-- =============================================================================
-- CAR RENTAL SYSTEM - ORACLE PACKAGES, PROCEDURES & FUNCTIONS
-- Demonstrates: Package spec/body, cursors, REF CURSOR, bulk collect,
--               FORALL, pipelined functions, autonomous transactions,
--               dynamic SQL (EXECUTE IMMEDIATE), collections, exceptions
-- =============================================================================

-- ========================
-- PACKAGE: car_rental_pkg
-- ========================
CREATE OR REPLACE PACKAGE car_rental_pkg AS

    -- Custom exceptions
    ex_vehicle_unavailable  EXCEPTION;
    ex_invalid_dates        EXCEPTION;
    ex_customer_blacklisted EXCEPTION;
    PRAGMA EXCEPTION_INIT(ex_vehicle_unavailable,  -20010);
    PRAGMA EXCEPTION_INIT(ex_invalid_dates,        -20011);
    PRAGMA EXCEPTION_INIT(ex_customer_blacklisted, -20012);

    -- Type definitions
    TYPE t_rental_summary IS RECORD (
        rental_id      rentals.rental_id%TYPE,
        customer_name  VARCHAR2(101),
        vehicle_info   VARCHAR2(100),
        pickup_date    TIMESTAMP,
        total_charge   NUMBER
    );
    TYPE t_rental_list IS TABLE OF t_rental_summary;

    TYPE t_rev_row IS RECORD (
        period_label  VARCHAR2(20),
        rental_count  NUMBER,
        total_revenue NUMBER
    );
    TYPE t_rev_tab IS TABLE OF t_rev_row;

    -- Public subprogram signatures
    FUNCTION  make_reservation(
        p_customer_id      IN NUMBER,
        p_vehicle_id       IN NUMBER,
        p_pickup_location  IN NUMBER,
        p_dropoff_location IN NUMBER,
        p_pickup_date      IN DATE,
        p_dropoff_date     IN DATE,
        p_promo_code       IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    PROCEDURE begin_rental(
        p_reservation_id IN NUMBER,
        p_employee_id    IN NUMBER,
        p_odometer_out   IN NUMBER,
        p_rental_id      OUT NUMBER
    );

    PROCEDURE complete_rental(
        p_rental_id     IN NUMBER,
        p_employee_id   IN NUMBER,
        p_odometer_in   IN NUMBER,
        p_fuel_level_in IN NUMBER,
        p_damage_notes  IN CLOB DEFAULT NULL
    );

    FUNCTION get_active_rentals(
        p_location_id IN NUMBER DEFAULT NULL
    ) RETURN t_rental_list PIPELINED;

    FUNCTION calculate_charge(
        p_vehicle_id   IN NUMBER,
        p_pickup_date  IN DATE,
        p_dropoff_date IN DATE,
        p_promo_code   IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    FUNCTION revenue_by_month(
        p_start_date IN DATE,
        p_end_date   IN DATE
    ) RETURN t_rev_tab PIPELINED;

    PROCEDURE purge_old_audit_logs(p_days_to_keep IN NUMBER DEFAULT 90);

END car_rental_pkg;
/


CREATE OR REPLACE PACKAGE BODY car_rental_pkg AS

    -- -----------------------------------------------------------------------
    -- Private: log audit with autonomous transaction
    -- -----------------------------------------------------------------------
    PROCEDURE log_audit(
        p_table     IN VARCHAR2,
        p_op        IN VARCHAR2,
        p_record_id IN NUMBER,
        p_note      IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO audit_log(table_name, operation, record_id, new_values)
        VALUES (p_table, p_op, p_record_id, p_note);
        COMMIT;
    END log_audit;

    -- -----------------------------------------------------------------------
    -- FUNCTION: calculate_charge
    -- Uses: CASE expression, NVL, analytic window
    -- -----------------------------------------------------------------------
    FUNCTION calculate_charge(
        p_vehicle_id   IN NUMBER,
        p_pickup_date  IN DATE,
        p_dropoff_date IN DATE,
        p_promo_code   IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER IS
        v_days         NUMBER;
        v_daily_rate   NUMBER;
        v_weekly_rate  NUMBER;
        v_monthly_rate NUMBER;
        v_override     NUMBER;
        v_base         NUMBER;
        v_discount     NUMBER := 0;
    BEGIN
        v_days := GREATEST(1, p_dropoff_date - p_pickup_date);

        SELECT vc.daily_rate, vc.weekly_rate, vc.monthly_rate, v.daily_override
          INTO v_daily_rate, v_weekly_rate, v_monthly_rate, v_override
          FROM vehicles v
          JOIN vehicle_categories vc ON v.category_id = vc.category_id
         WHERE v.vehicle_id = p_vehicle_id;

        -- Use override if set, otherwise category rate
        v_daily_rate := NVL(v_override, v_daily_rate);

        -- Tiered pricing with CASE
        v_base := CASE
            WHEN v_days >= 28 THEN
                FLOOR(v_days / 28) * 28 * NVL(v_monthly_rate, v_daily_rate * 0.65) / 28
                + MOD(v_days, 28) * NVL(v_weekly_rate, v_daily_rate * 0.80) / 7
            WHEN v_days >= 7 THEN
                FLOOR(v_days / 7) * 7 * NVL(v_weekly_rate, v_daily_rate * 0.80) / 7
                + MOD(v_days, 7) * v_daily_rate
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
               AND SYSDATE BETWEEN valid_from AND valid_to;
        END IF;

        RETURN ROUND(v_base - v_discount, 2);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN NULL;
    END calculate_charge;

    -- -----------------------------------------------------------------------
    -- FUNCTION: make_reservation
    -- Uses: SELECT FOR UPDATE, MERGE, sequence.NEXTVAL
    -- -----------------------------------------------------------------------
    FUNCTION make_reservation(
        p_customer_id      IN NUMBER,
        p_vehicle_id       IN NUMBER,
        p_pickup_location  IN NUMBER,
        p_dropoff_location IN NUMBER,
        p_pickup_date      IN DATE,
        p_dropoff_date     IN DATE,
        p_promo_code       IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER IS
        v_res_id    NUMBER;
        v_status    VARCHAR2(20);
        v_tier      VARCHAR2(10);
        v_cost      NUMBER;
        v_discount  NUMBER := 0;
        v_overlap   NUMBER;
    BEGIN
        -- Validate dates
        IF p_dropoff_date <= p_pickup_date THEN
            RAISE ex_invalid_dates;
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
            RAISE ex_vehicle_unavailable;
        END IF;

        -- Check customer standing using WITH clause
        WITH customer_info AS (
            SELECT tier, loyalty_points
              FROM customers
             WHERE customer_id = p_customer_id
               AND is_active = 'Y'
        )
        SELECT tier INTO v_tier FROM customer_info;

        -- Loyalty discount
        v_cost := calculate_charge(p_vehicle_id, p_pickup_date, p_dropoff_date, p_promo_code);
        v_discount := CASE v_tier
                          WHEN 'GOLD'     THEN v_cost * 0.05
                          WHEN 'PLATINUM' THEN v_cost * 0.10
                          ELSE 0
                      END;
        v_cost := v_cost - v_discount;

        -- Insert reservation
        v_res_id := seq_reservation_id.NEXTVAL;
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

        -- Update promo code usage with MERGE
        IF p_promo_code IS NOT NULL THEN
            MERGE INTO promo_codes pc
            USING (SELECT p_promo_code AS pc_code FROM dual) src
               ON (pc.promo_code = src.pc_code)
             WHEN MATCHED THEN
                UPDATE SET pc.current_uses = pc.current_uses + 1;
        END IF;

        log_audit('RESERVATIONS','INSERT', v_res_id,
                  'customer=' || p_customer_id || ',vehicle=' || p_vehicle_id);
        COMMIT;
        RETURN v_res_id;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20013, 'Customer not found or inactive');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END make_reservation;

    -- -----------------------------------------------------------------------
    -- PROCEDURE: begin_rental
    -- -----------------------------------------------------------------------
    PROCEDURE begin_rental(
        p_reservation_id IN NUMBER,
        p_employee_id    IN NUMBER,
        p_odometer_out   IN NUMBER,
        p_rental_id      OUT NUMBER
    ) IS
        v_vehicle_id     NUMBER;
        v_customer_id    NUMBER;
        v_pickup_loc     NUMBER;
        v_dropoff_loc    NUMBER;
    BEGIN
        -- Lock reservation row
        SELECT vehicle_id, customer_id, pickup_location, dropoff_location
          INTO v_vehicle_id, v_customer_id, v_pickup_loc, v_dropoff_loc
          FROM reservations
         WHERE reservation_id = p_reservation_id
           AND status = 'CONFIRMED'
         FOR UPDATE OF status NOWAIT;

        p_rental_id := seq_rental_id.NEXTVAL;

        INSERT INTO rentals (
            rental_id, reservation_id, customer_id, vehicle_id,
            pickup_location, dropoff_location,
            actual_pickup, odometer_out,
            employee_out, status
        ) VALUES (
            p_rental_id, p_reservation_id, v_customer_id, v_vehicle_id,
            v_pickup_loc, v_dropoff_loc,
            SYSTIMESTAMP, p_odometer_out,
            p_employee_id, 'ACTIVE'
        );

        UPDATE reservations
           SET status = 'COMPLETED'
         WHERE reservation_id = p_reservation_id;

        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20014, 'Reservation not found or not in CONFIRMED status');
    END begin_rental;

    -- -----------------------------------------------------------------------
    -- PROCEDURE: complete_rental
    -- Uses: Computed charges, UPDATE with expression
    -- -----------------------------------------------------------------------
    PROCEDURE complete_rental(
        p_rental_id     IN NUMBER,
        p_employee_id   IN NUMBER,
        p_odometer_in   IN NUMBER,
        p_fuel_level_in IN NUMBER,
        p_damage_notes  IN CLOB DEFAULT NULL
    ) IS
        v_vehicle_id    NUMBER;
        v_daily_rate    NUMBER;
        v_out_ts        TIMESTAMP;
        v_days          NUMBER;
        v_base_charge   NUMBER;
        v_fuel_charge   NUMBER := 0;
        v_damage_charge NUMBER := 0;
        v_late_fee      NUMBER := 0;
        v_fuel_out      NUMBER;
        v_promo         VARCHAR2(20);
        v_total         NUMBER;
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
         FOR UPDATE NOWAIT;

        -- Calculate actual days
        v_days := GREATEST(1, CEIL((SYSTIMESTAMP - v_out_ts) * 24 / 24));

        -- Fuel surcharge: $3 per missing percentage point
        IF p_fuel_level_in < v_fuel_out THEN
            v_fuel_charge := (v_fuel_out - p_fuel_level_in) * 3;
        END IF;

        -- Damage charge from notes
        IF p_damage_notes IS NOT NULL AND DBMS_LOB.GETLENGTH(p_damage_notes) > 0 THEN
            v_damage_charge := 250;  -- flat damage assessment fee
        END IF;

        -- Late fee: 1.5x daily rate per day late
        IF v_reserved_drop IS NOT NULL AND TRUNC(SYSTIMESTAMP) > v_reserved_drop THEN
            v_late_fee := GREATEST(0, TRUNC(SYSTIMESTAMP) - v_reserved_drop)
                          * v_daily_rate * 1.5;
        END IF;

        v_base_charge := calculate_charge(v_vehicle_id, TRUNC(v_out_ts), TRUNC(SYSTIMESTAMP), v_promo);
        v_total := NVL(v_base_charge, 0) + v_fuel_charge + v_damage_charge + v_late_fee;

        UPDATE rentals
           SET status         = 'COMPLETED',
               actual_dropoff = SYSTIMESTAMP,
               odometer_in    = p_odometer_in,
               fuel_level_in  = p_fuel_level_in,
               base_charge    = v_base_charge,
               fuel_charge    = v_fuel_charge,
               damage_charge  = v_damage_charge,
               late_fee       = v_late_fee,
               total_charge   = v_total,
               employee_in    = p_employee_id,
               damage_notes   = p_damage_notes,
               updated_at     = SYSTIMESTAMP
         WHERE rental_id = p_rental_id;

        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20015, 'Active rental not found: ' || p_rental_id);
    END complete_rental;

    -- -----------------------------------------------------------------------
    -- PIPELINED FUNCTION: get_active_rentals
    -- -----------------------------------------------------------------------
    FUNCTION get_active_rentals(
        p_location_id IN NUMBER DEFAULT NULL
    ) RETURN t_rental_list PIPELINED IS
        CURSOR c_rentals IS
            SELECT r.rental_id,
                   c.first_name || ' ' || c.last_name AS customer_name,
                   v.make || ' ' || v.model || ' (' || v.model_year || ')' AS vehicle_info,
                   r.actual_pickup,
                   r.total_charge
              FROM rentals r
              JOIN customers c ON r.customer_id = c.customer_id
              JOIN vehicles  v ON r.vehicle_id  = v.vehicle_id
             WHERE r.status = 'ACTIVE'
               AND (p_location_id IS NULL OR r.pickup_location = p_location_id)
             ORDER BY r.actual_pickup;
        v_row t_rental_summary;
    BEGIN
        FOR rec IN c_rentals LOOP
            v_row.rental_id     := rec.rental_id;
            v_row.customer_name := rec.customer_name;
            v_row.vehicle_info  := rec.vehicle_info;
            v_row.pickup_date   := rec.actual_pickup;
            v_row.total_charge  := rec.total_charge;
            PIPE ROW(v_row);
        END LOOP;
        RETURN;
    END get_active_rentals;

    -- -----------------------------------------------------------------------
    -- PIPELINED FUNCTION: revenue_by_month
    -- Uses: TRUNC with 'MM', GROUP BY, ROLLUP
    -- -----------------------------------------------------------------------
    FUNCTION revenue_by_month(
        p_start_date IN DATE,
        p_end_date   IN DATE
    ) RETURN t_rev_tab PIPELINED IS
        v_row t_rev_row;
    BEGIN
        FOR rec IN (
            SELECT TO_CHAR(TRUNC(actual_dropoff,'MM'),'YYYY-MM') AS period_label,
                   COUNT(*)       AS rental_count,
                   SUM(total_charge) AS total_revenue
              FROM rentals
             WHERE status = 'COMPLETED'
               AND TRUNC(actual_dropoff) BETWEEN p_start_date AND p_end_date
             GROUP BY ROLLUP(TRUNC(actual_dropoff,'MM'))
             ORDER BY TRUNC(actual_dropoff,'MM')
        ) LOOP
            v_row.period_label  := NVL(rec.period_label, 'TOTAL');
            v_row.rental_count  := rec.rental_count;
            v_row.total_revenue := rec.total_revenue;
            PIPE ROW(v_row);
        END LOOP;
        RETURN;
    END revenue_by_month;

    -- -----------------------------------------------------------------------
    -- PROCEDURE: purge_old_audit_logs (bulk delete with FORALL)
    -- -----------------------------------------------------------------------
    PROCEDURE purge_old_audit_logs(p_days_to_keep IN NUMBER DEFAULT 90) IS
        TYPE t_id_list IS TABLE OF audit_log.audit_id%TYPE;
        v_ids   t_id_list;
        v_cutoff DATE := SYSDATE - p_days_to_keep;
    BEGIN
        SELECT audit_id
          BULK COLLECT INTO v_ids
          FROM audit_log
         WHERE changed_at < v_cutoff;

        FORALL i IN 1..v_ids.COUNT
            DELETE FROM audit_log WHERE audit_id = v_ids(i);

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Purged ' || v_ids.COUNT || ' audit log records');
    END purge_old_audit_logs;

END car_rental_pkg;
/

-- ========================
-- STANDALONE: Reporting functions
-- ========================

-- Function: Get vehicle utilization rate
CREATE OR REPLACE FUNCTION get_vehicle_utilization(
    p_vehicle_id IN NUMBER,
    p_start_date IN DATE,
    p_end_date   IN DATE
) RETURN NUMBER IS
    v_rented_days NUMBER;
    v_total_days  NUMBER;
BEGIN
    v_total_days := p_end_date - p_start_date;
    IF v_total_days <= 0 THEN RETURN 0; END IF;

    SELECT NVL(SUM(
               LEAST(TRUNC(actual_dropoff), p_end_date)
               - GREATEST(TRUNC(actual_pickup), p_start_date)
           ), 0)
      INTO v_rented_days
      FROM rentals
     WHERE vehicle_id = p_vehicle_id
       AND status = 'COMPLETED'
       AND actual_pickup < p_end_date
       AND actual_dropoff > p_start_date;

    RETURN ROUND(v_rented_days / v_total_days * 100, 2);
END;
/

-- ========================
-- VIEWS
-- ========================

-- View: Active rentals with customer & vehicle info
CREATE OR REPLACE VIEW v_active_rentals AS
    SELECT r.rental_id,
           r.customer_id,
           c.first_name || ' ' || c.last_name   AS customer_name,
           c.email                               AS customer_email,
           r.vehicle_id,
           v.make || ' ' || v.model              AS vehicle,
           v.license_plate,
           l_pick.location_name                  AS pickup_location,
           l_drop.location_name                  AS dropoff_location,
           r.actual_pickup,
           ROUND((SYSTIMESTAMP - r.actual_pickup) * 24, 1) AS hours_out,
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
CREATE OR REPLACE VIEW v_revenue_dashboard AS
    SELECT TO_CHAR(TRUNC(actual_dropoff,'MM'),'Mon YYYY')    AS month,
           COUNT(*)                                           AS rentals,
           ROUND(SUM(total_charge),2)                        AS total_revenue,
           ROUND(AVG(total_charge),2)                        AS avg_revenue,
           ROUND(SUM(SUM(total_charge)) OVER (
               ORDER BY TRUNC(actual_dropoff,'MM')
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ), 2)                                             AS running_total,
           ROUND(AVG(SUM(total_charge)) OVER (
               ORDER BY TRUNC(actual_dropoff,'MM')
               ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
           ), 2)                                             AS moving_avg_3m
      FROM rentals
     WHERE status = 'COMPLETED'
     GROUP BY TRUNC(actual_dropoff,'MM')
     ORDER BY TRUNC(actual_dropoff,'MM');

-- View: Vehicle availability with current status
CREATE OR REPLACE VIEW v_vehicle_availability AS
    SELECT v.vehicle_id,
           v.make, v.model, v.model_year,
           v.license_plate, v.color,
           vc.category_name,
           NVL(v.daily_override, vc.daily_rate) AS daily_rate,
           l.location_name,
           v.status,
           v.mileage,
           CASE WHEN v.insurance_expiry < SYSDATE
                THEN 'EXPIRED' ELSE 'VALID' END  AS insurance_status,
           v.last_service_date
      FROM vehicles v
      JOIN vehicle_categories vc ON v.category_id  = vc.category_id
      LEFT JOIN locations     l  ON v.location_id  = l.location_id
     WHERE v.is_active = 'Y';

-- Materialized View: monthly revenue snapshot (refresh daily)
CREATE MATERIALIZED VIEW mv_monthly_revenue
    REFRESH COMPLETE START WITH SYSDATE NEXT TRUNC(SYSDATE+1) + 2/24
AS
    SELECT TRUNC(actual_dropoff,'MM')    AS revenue_month,
           COUNT(*)                      AS rental_count,
           SUM(total_charge)             AS total_revenue,
           AVG(total_charge)             AS avg_charge,
           MAX(total_charge)             AS max_charge,
           MIN(total_charge)             AS min_charge
      FROM rentals
     WHERE status = 'COMPLETED'
     GROUP BY TRUNC(actual_dropoff,'MM');
