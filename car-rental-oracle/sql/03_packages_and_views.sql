-- =============================================================================
-- CAR RENTAL SYSTEM - POSTGRESQL FUNCTIONS, PROCEDURES & VIEWS
-- Migrated from Oracle: car_rental_pkg package + standalone function + views
--
-- Conversion summary:
--   PACKAGE spec/body         → individual PL/pgSQL functions
--   SYSTIMESTAMP               → NOW()
--   SYSDATE                    → CURRENT_DATE / NOW()
--   NVL()                      → COALESCE()
--   TRUNC(d,'MM')              → DATE_TRUNC('month', d)
--   seq_X.NEXTVAL              → NEXTVAL('seq_X')
--   PRAGMA AUTONOMOUS_TRANSACTION → separate function with no txn dependency
--   RAISE_APPLICATION_ERROR()  → RAISE EXCEPTION ... USING ERRCODE='P0001'
--   DBMS_OUTPUT.PUT_LINE       → RAISE NOTICE
--   DBMS_LOB.GETLENGTH()       → LENGTH() / OCTET_LENGTH()
--   Pipelined functions        → RETURNS TABLE(...) with RETURN QUERY
--   FORALL / BULK COLLECT      → plain DELETE WHERE id = ANY(array)
--   MERGE INTO ... USING dual  → INSERT ... ON CONFLICT DO UPDATE
--   Materialized view refresh  → bare CREATE MATERIALIZED VIEW
-- =============================================================================

-- ========================
-- log_audit (replaces Oracle autonomous-transaction private procedure)
-- Uses a plain INSERT; caller must handle commit separately
-- ========================
CREATE OR REPLACE FUNCTION log_audit(
    p_table     VARCHAR,
    p_op        VARCHAR,
    p_record_id BIGINT,
    p_note      VARCHAR
) RETURNS VOID AS $$
BEGIN
    INSERT INTO audit_log(table_name, operation, record_id, new_values)
    VALUES (p_table, p_op, p_record_id, p_note);
END;
$$ LANGUAGE plpgsql;


-- ========================
-- calculate_charge
-- ========================
CREATE OR REPLACE FUNCTION calculate_charge(
    p_vehicle_id   BIGINT,
    p_pickup_date  DATE,
    p_dropoff_date DATE,
    p_promo_code   VARCHAR DEFAULT NULL
) RETURNS NUMERIC AS $$
DECLARE
    v_days         NUMERIC;
    v_daily_rate   NUMERIC;
    v_weekly_rate  NUMERIC;
    v_monthly_rate NUMERIC;
    v_override     NUMERIC;
    v_base         NUMERIC;
    v_discount     NUMERIC := 0;
BEGIN
    v_days := GREATEST(1, p_dropoff_date - p_pickup_date);

    SELECT vc.daily_rate, vc.weekly_rate, vc.monthly_rate, v.daily_override
      INTO v_daily_rate, v_weekly_rate, v_monthly_rate, v_override
      FROM vehicles v
      JOIN vehicle_categories vc ON v.category_id = vc.category_id
     WHERE v.vehicle_id = p_vehicle_id;

    -- Use override if set, otherwise category rate
    v_daily_rate := COALESCE(v_override, v_daily_rate);

    -- Tiered pricing
    v_base := CASE
        WHEN v_days >= 28 THEN
            FLOOR(v_days / 28) * 28 * COALESCE(v_monthly_rate, v_daily_rate * 0.65) / 28
            + MOD(v_days::INTEGER, 28) * COALESCE(v_weekly_rate, v_daily_rate * 0.80) / 7
        WHEN v_days >= 7 THEN
            FLOOR(v_days / 7) * 7 * COALESCE(v_weekly_rate, v_daily_rate * 0.80) / 7
            + MOD(v_days::INTEGER, 7) * v_daily_rate
        ELSE
            v_days * v_daily_rate
    END;

    -- Apply promo discount
    IF p_promo_code IS NOT NULL THEN
        SELECT CASE discount_type
                   WHEN 'PERCENT' THEN v_base * (discount_value / 100)
                   WHEN 'FIXED'   THEN LEAST(discount_value, v_base)
                   ELSE 0
               END
          INTO v_discount
          FROM promo_codes
         WHERE promo_code = p_promo_code
           AND is_active  = 'Y'
           AND CURRENT_DATE BETWEEN valid_from AND valid_to;
    END IF;

    RETURN ROUND(v_base - COALESCE(v_discount, 0), 2);
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
END;
$$ LANGUAGE plpgsql;


-- ========================
-- make_reservation
-- MERGE INTO ... USING dual → INSERT ON CONFLICT DO UPDATE
-- ========================
CREATE OR REPLACE FUNCTION make_reservation(
    p_customer_id      BIGINT,
    p_vehicle_id       BIGINT,
    p_pickup_location  INTEGER,
    p_dropoff_location INTEGER,
    p_pickup_date      DATE,
    p_dropoff_date     DATE,
    p_promo_code       VARCHAR DEFAULT NULL
) RETURNS BIGINT AS $$
DECLARE
    v_res_id    BIGINT;
    v_tier      VARCHAR(10);
    v_cost      NUMERIC;
    v_discount  NUMERIC := 0;
    v_overlap   INTEGER;
BEGIN
    -- Validate dates
    IF p_dropoff_date <= p_pickup_date THEN
        RAISE EXCEPTION 'Drop-off date must be after pick-up date' USING ERRCODE = 'P0001';
    END IF;

    -- Check vehicle availability during requested period
    SELECT COUNT(*) INTO v_overlap
      FROM rentals r
      JOIN reservations rs ON r.reservation_id = rs.reservation_id
     WHERE rs.vehicle_id = p_vehicle_id
       AND rs.status NOT IN ('CANCELLED','NO_SHOW')
       AND rs.pickup_date  < p_dropoff_date
       AND rs.dropoff_date > p_pickup_date;

    IF v_overlap > 0 THEN
        RAISE EXCEPTION 'Vehicle is not available for the requested period' USING ERRCODE = 'P0001';
    END IF;

    -- Check customer standing using CTE
    SELECT tier INTO v_tier
      FROM customers
     WHERE customer_id = p_customer_id
       AND is_active = 'Y';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer not found or inactive' USING ERRCODE = 'P0001';
    END IF;

    -- Loyalty discount
    v_cost := calculate_charge(p_vehicle_id, p_pickup_date, p_dropoff_date, p_promo_code);
    v_discount := CASE v_tier
                      WHEN 'GOLD'     THEN v_cost * 0.05
                      WHEN 'PLATINUM' THEN v_cost * 0.10
                      ELSE 0
                  END;
    v_cost := v_cost - v_discount;

    -- Insert reservation
    v_res_id := NEXTVAL('seq_reservation_id');
    INSERT INTO reservations (
        reservation_id, customer_id, vehicle_id,
        pickup_location, dropoff_location,
        pickup_date, dropoff_date,
        estimated_cost, promo_code, status
    ) VALUES (
        v_res_id, p_customer_id, p_vehicle_id,
        p_pickup_location, p_dropoff_location,
        p_pickup_date, p_dropoff_date,
        ROUND(v_cost, 2), p_promo_code, 'CONFIRMED'
    );

    -- Update promo code usage — INSERT ON CONFLICT replaces Oracle MERGE
    IF p_promo_code IS NOT NULL THEN
        INSERT INTO promo_codes(promo_code, current_uses)
        VALUES (p_promo_code, 1)
        ON CONFLICT (promo_code)
        DO UPDATE SET current_uses = promo_codes.current_uses + 1;
    END IF;

    PERFORM log_audit('RESERVATIONS', 'INSERT', v_res_id,
                      'customer=' || p_customer_id || ',vehicle=' || p_vehicle_id);

    RETURN v_res_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql;


-- ========================
-- begin_rental
-- ========================
CREATE OR REPLACE FUNCTION begin_rental(
    p_reservation_id BIGINT,
    p_employee_id    BIGINT,
    p_odometer_out   BIGINT
) RETURNS BIGINT AS $$
DECLARE
    v_vehicle_id  BIGINT;
    v_customer_id BIGINT;
    v_pickup_loc  INTEGER;
    v_dropoff_loc INTEGER;
    v_rental_id   BIGINT;
BEGIN
    -- Lock reservation row
    SELECT vehicle_id, customer_id, pickup_location, dropoff_location
      INTO v_vehicle_id, v_customer_id, v_pickup_loc, v_dropoff_loc
      FROM reservations
     WHERE reservation_id = p_reservation_id
       AND status = 'CONFIRMED'
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation not found or not in CONFIRMED status' USING ERRCODE = 'P0001';
    END IF;

    v_rental_id := NEXTVAL('seq_rental_id');

    INSERT INTO rentals (
        rental_id, reservation_id, customer_id, vehicle_id,
        pickup_location, dropoff_location,
        actual_pickup, odometer_out,
        employee_out, status
    ) VALUES (
        v_rental_id, p_reservation_id, v_customer_id, v_vehicle_id,
        v_pickup_loc, v_dropoff_loc,
        NOW(), p_odometer_out,
        p_employee_id, 'ACTIVE'
    );

    UPDATE reservations
       SET status = 'COMPLETED'
     WHERE reservation_id = p_reservation_id;

    RETURN v_rental_id;
END;
$$ LANGUAGE plpgsql;


-- ========================
-- complete_rental
-- DBMS_LOB.GETLENGTH() → LENGTH() / OCTET_LENGTH()
-- ========================
CREATE OR REPLACE FUNCTION complete_rental(
    p_rental_id     BIGINT,
    p_employee_id   BIGINT,
    p_odometer_in   BIGINT,
    p_fuel_level_in INTEGER,
    p_damage_notes  TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_vehicle_id    BIGINT;
    v_daily_rate    NUMERIC;
    v_out_ts        TIMESTAMPTZ;
    v_days          NUMERIC;
    v_base_charge   NUMERIC;
    v_fuel_charge   NUMERIC := 0;
    v_damage_charge NUMERIC := 0;
    v_late_fee      NUMERIC := 0;
    v_fuel_out      INTEGER;
    v_promo         VARCHAR(20);
    v_total         NUMERIC;
    v_reserved_drop DATE;
BEGIN
    -- Get rental details with JOIN
    SELECT r.vehicle_id, r.actual_pickup, r.fuel_level_out,
           res.dropoff_date, res.promo_code
      INTO v_vehicle_id, v_out_ts, v_fuel_out,
           v_reserved_drop, v_promo
      FROM rentals r
      LEFT JOIN reservations res ON r.reservation_id = res.reservation_id
     WHERE r.rental_id = p_rental_id
       AND r.status = 'ACTIVE'
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Active rental not found: %', p_rental_id USING ERRCODE = 'P0001';
    END IF;

    -- Calculate actual days
    v_days := GREATEST(1, CEIL(EXTRACT(EPOCH FROM (NOW() - v_out_ts)) / 86400));

    -- Fuel surcharge: $3 per missing percentage point
    IF p_fuel_level_in < v_fuel_out THEN
        v_fuel_charge := (v_fuel_out - p_fuel_level_in) * 3;
    END IF;

    -- Damage charge from notes
    IF p_damage_notes IS NOT NULL AND LENGTH(p_damage_notes) > 0 THEN
        v_damage_charge := 250;  -- flat damage assessment fee
    END IF;

    -- Late fee: 1.5x daily rate per day late
    IF v_reserved_drop IS NOT NULL AND NOW()::DATE > v_reserved_drop THEN
        v_late_fee := GREATEST(0, (NOW()::DATE - v_reserved_drop))
                      * v_daily_rate * 1.5;
    END IF;

    v_base_charge := calculate_charge(v_vehicle_id,
                                      DATE_TRUNC('day', v_out_ts)::DATE,
                                      NOW()::DATE,
                                      v_promo);
    v_total := COALESCE(v_base_charge, 0) + v_fuel_charge + v_damage_charge + v_late_fee;

    UPDATE rentals
       SET status         = 'COMPLETED',
           actual_dropoff = NOW(),
           odometer_in    = p_odometer_in,
           fuel_level_in  = p_fuel_level_in,
           base_charge    = v_base_charge,
           fuel_charge    = v_fuel_charge,
           damage_charge  = v_damage_charge,
           late_fee       = v_late_fee,
           total_charge   = v_total,
           employee_in    = p_employee_id,
           damage_notes   = p_damage_notes,
           updated_at     = NOW()
     WHERE rental_id = p_rental_id;
END;
$$ LANGUAGE plpgsql;


-- ========================
-- get_active_rentals — replaces Oracle pipelined function
-- Returns TABLE(...) via RETURN QUERY
-- ========================
CREATE OR REPLACE FUNCTION get_active_rentals(
    p_location_id INTEGER DEFAULT NULL
) RETURNS TABLE (
    rental_id     BIGINT,
    customer_name VARCHAR,
    vehicle_info  VARCHAR,
    pickup_date   TIMESTAMPTZ,
    total_charge  NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT r.rental_id,
           (c.first_name || ' ' || c.last_name)::VARCHAR          AS customer_name,
           (v.make || ' ' || v.model || ' (' || v.model_year::TEXT || ')')::VARCHAR AS vehicle_info,
           r.actual_pickup,
           r.total_charge
      FROM rentals r
      JOIN customers c ON r.customer_id = c.customer_id
      JOIN vehicles  v ON r.vehicle_id  = v.vehicle_id
     WHERE r.status = 'ACTIVE'
       AND (p_location_id IS NULL OR r.pickup_location = p_location_id)
     ORDER BY r.actual_pickup;
END;
$$ LANGUAGE plpgsql;


-- ========================
-- revenue_by_month — replaces Oracle pipelined function
-- Returns TABLE(...) via RETURN QUERY
-- ========================
CREATE OR REPLACE FUNCTION revenue_by_month(
    p_start_date DATE,
    p_end_date   DATE
) RETURNS TABLE (
    period_label  VARCHAR,
    rental_count  BIGINT,
    total_revenue NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT COALESCE(TO_CHAR(DATE_TRUNC('month', actual_dropoff), 'YYYY-MM'), 'TOTAL')::VARCHAR,
           COUNT(*),
           SUM(total_charge)
      FROM rentals
     WHERE status = 'COMPLETED'
       AND actual_dropoff::DATE BETWEEN p_start_date AND p_end_date
     GROUP BY ROLLUP(DATE_TRUNC('month', actual_dropoff))
     ORDER BY DATE_TRUNC('month', actual_dropoff) NULLS LAST;
END;
$$ LANGUAGE plpgsql;


-- ========================
-- purge_old_audit_logs
-- FORALL / BULK COLLECT → plain DELETE WHERE id = ANY(array)
-- DBMS_OUTPUT → RAISE NOTICE
-- ========================
CREATE OR REPLACE FUNCTION purge_old_audit_logs(
    p_days_to_keep INTEGER DEFAULT 90
) RETURNS VOID AS $$
DECLARE
    v_cutoff   TIMESTAMPTZ := NOW() - (p_days_to_keep || ' days')::INTERVAL;
    v_count    INTEGER;
BEGIN
    DELETE FROM audit_log
     WHERE changed_at < v_cutoff;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Purged % audit log records', v_count;
END;
$$ LANGUAGE plpgsql;


-- ========================
-- get_vehicle_utilization — standalone function
-- NVL → COALESCE; no FROM dual
-- ========================
CREATE OR REPLACE FUNCTION get_vehicle_utilization(
    p_vehicle_id BIGINT,
    p_start_date DATE,
    p_end_date   DATE
) RETURNS NUMERIC AS $$
DECLARE
    v_rented_days NUMERIC;
    v_total_days  NUMERIC;
BEGIN
    v_total_days := p_end_date - p_start_date;
    IF v_total_days <= 0 THEN RETURN 0; END IF;

    SELECT COALESCE(SUM(
               LEAST(actual_dropoff::DATE, p_end_date)
               - GREATEST(actual_pickup::DATE, p_start_date)
           ), 0)
      INTO v_rented_days
      FROM rentals
     WHERE vehicle_id = p_vehicle_id
       AND status = 'COMPLETED'
       AND actual_pickup  < p_end_date
       AND actual_dropoff > p_start_date;

    RETURN ROUND(v_rented_days / v_total_days * 100, 2);
END;
$$ LANGUAGE plpgsql;


-- ========================
-- VIEWS
-- ========================

-- View: Active rentals with customer & vehicle info
-- ROUND((SYSTIMESTAMP - actual_pickup)*24,1) → EXTRACT(EPOCH FROM ...) / 3600
CREATE OR REPLACE VIEW v_active_rentals AS
    SELECT r.rental_id,
           r.customer_id,
           c.first_name || ' ' || c.last_name           AS customer_name,
           c.email                                       AS customer_email,
           r.vehicle_id,
           v.make || ' ' || v.model                     AS vehicle,
           v.license_plate,
           l_pick.location_name                         AS pickup_location,
           l_drop.location_name                         AS dropoff_location,
           r.actual_pickup,
           ROUND(EXTRACT(EPOCH FROM (NOW() - r.actual_pickup)) / 3600::NUMERIC, 1) AS hours_out,
           r.odometer_out,
           r.base_charge,
           r.status
      FROM rentals     r
      JOIN customers   c      ON r.customer_id      = c.customer_id
      JOIN vehicles    v      ON r.vehicle_id        = v.vehicle_id
      JOIN locations   l_pick ON r.pickup_location   = l_pick.location_id
      JOIN locations   l_drop ON r.dropoff_location  = l_drop.location_id
     WHERE r.status = 'ACTIVE';

-- View: Revenue dashboard with analytic functions
-- TRUNC(d,'MM') → DATE_TRUNC('month',d)
-- Window functions are ANSI SQL — no change needed
CREATE OR REPLACE VIEW v_revenue_dashboard AS
    SELECT TO_CHAR(DATE_TRUNC('month', actual_dropoff), 'Mon YYYY')  AS month,
           COUNT(*)                                                   AS rentals,
           ROUND(SUM(total_charge),2)                                AS total_revenue,
           ROUND(AVG(total_charge),2)                                AS avg_revenue,
           ROUND(SUM(SUM(total_charge)) OVER (
               ORDER BY DATE_TRUNC('month', actual_dropoff)
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ), 2)                                                      AS running_total,
           ROUND(AVG(SUM(total_charge)) OVER (
               ORDER BY DATE_TRUNC('month', actual_dropoff)
               ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
           ), 2)                                                      AS moving_avg_3m
      FROM rentals
     WHERE status = 'COMPLETED'
     GROUP BY DATE_TRUNC('month', actual_dropoff)
     ORDER BY DATE_TRUNC('month', actual_dropoff);

-- View: Vehicle availability with current status
-- NVL → COALESCE; SYSDATE → CURRENT_DATE
CREATE OR REPLACE VIEW v_vehicle_availability AS
    SELECT v.vehicle_id,
           v.make, v.model, v.model_year,
           v.license_plate, v.color,
           vc.category_name,
           COALESCE(v.daily_override, vc.daily_rate) AS daily_rate,
           l.location_name,
           v.status,
           v.mileage,
           CASE WHEN v.insurance_expiry < CURRENT_DATE
                THEN 'EXPIRED' ELSE 'VALID' END      AS insurance_status,
           v.last_service_date
      FROM vehicles v
      JOIN vehicle_categories vc ON v.category_id  = vc.category_id
      LEFT JOIN locations     l  ON v.location_id  = l.location_id
     WHERE v.is_active = 'Y';

-- Materialized View: monthly revenue snapshot
-- Oracle: REFRESH COMPLETE START WITH SYSDATE NEXT TRUNC(...)
-- PostgreSQL: bare CREATE MATERIALIZED VIEW (refresh via cron/pg_cron externally)
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_monthly_revenue AS
    SELECT DATE_TRUNC('month', actual_dropoff)  AS revenue_month,
           COUNT(*)                             AS rental_count,
           SUM(total_charge)                   AS total_revenue,
           AVG(total_charge)                   AS avg_charge,
           MAX(total_charge)                   AS max_charge,
           MIN(total_charge)                   AS min_charge
      FROM rentals
     WHERE status = 'COMPLETED'
     GROUP BY DATE_TRUNC('month', actual_dropoff);

-- Refresh materialized view (run manually or schedule via pg_cron):
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_revenue;
