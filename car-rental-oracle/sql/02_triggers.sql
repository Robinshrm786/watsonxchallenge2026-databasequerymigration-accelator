-- =============================================================================
-- CAR RENTAL SYSTEM - ORACLE TRIGGERS
-- Demonstrates: BEFORE/AFTER row triggers, compound triggers,
--               INSTEAD OF triggers, DML triggers, DDL triggers,
--               :OLD / :NEW pseudo-records, autonomous transactions
-- =============================================================================

-- -------------------------
-- 1. BEFORE INSERT Trigger: Set PK from sequence if null (pre-12c style)
-- -------------------------
CREATE OR REPLACE TRIGGER trg_customers_bi
    BEFORE INSERT ON customers
    FOR EACH ROW
BEGIN
    IF :NEW.customer_id IS NULL THEN
        :NEW.customer_id := seq_customer_id.NEXTVAL;
    END IF;
    :NEW.created_at := SYSTIMESTAMP;
    :NEW.updated_at := SYSTIMESTAMP;
    -- Normalize tier based on loyalty points
    IF :NEW.loyalty_points < 500 THEN
        :NEW.tier := 'BRONZE';
    ELSIF :NEW.loyalty_points < 2000 THEN
        :NEW.tier := 'SILVER';
    ELSIF :NEW.loyalty_points < 5000 THEN
        :NEW.tier := 'GOLD';
    ELSE
        :NEW.tier := 'PLATINUM';
    END IF;
END;
/

-- -------------------------
-- 2. BEFORE UPDATE Trigger: Maintain updated_at, tier upgrade
-- -------------------------
CREATE OR REPLACE TRIGGER trg_customers_bu
    BEFORE UPDATE ON customers
    FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
    IF :NEW.loyalty_points < 500 THEN
        :NEW.tier := 'BRONZE';
    ELSIF :NEW.loyalty_points < 2000 THEN
        :NEW.tier := 'SILVER';
    ELSIF :NEW.loyalty_points < 5000 THEN
        :NEW.tier := 'GOLD';
    ELSE
        :NEW.tier := 'PLATINUM';
    END IF;
END;
/

-- -------------------------
-- 3. AFTER INSERT Trigger on Rentals: Update vehicle status
-- -------------------------
CREATE OR REPLACE TRIGGER trg_rentals_ai
    AFTER INSERT ON rentals
    FOR EACH ROW
BEGIN
    UPDATE vehicles
       SET status     = 'RENTED',
           updated_at = SYSTIMESTAMP
     WHERE vehicle_id = :NEW.vehicle_id;
END;
/

-- -------------------------
-- 4. AFTER UPDATE Trigger on Rentals: Return vehicle, add loyalty points
-- -------------------------
CREATE OR REPLACE TRIGGER trg_rentals_au
    AFTER UPDATE OF status ON rentals
    FOR EACH ROW
    WHEN (NEW.status = 'COMPLETED')
BEGIN
    -- Mark vehicle available again
    UPDATE vehicles
       SET status     = 'AVAILABLE',
           mileage    = NVL(:NEW.odometer_in, mileage),
           updated_at = SYSTIMESTAMP
     WHERE vehicle_id = :NEW.vehicle_id;

    -- Award loyalty points: 1 point per dollar spent
    UPDATE customers
       SET loyalty_points = loyalty_points + ROUND(NVL(:NEW.total_charge, 0)),
           updated_at     = SYSTIMESTAMP
     WHERE customer_id = :NEW.customer_id;
END;
/

-- -------------------------
-- 5. COMPOUND Trigger on Payments: Batch audit inserts (avoids mutating table)
-- -------------------------
CREATE OR REPLACE TRIGGER trg_payments_compound
    FOR INSERT OR UPDATE OR DELETE ON payments
    COMPOUND TRIGGER

    TYPE t_audit_row IS RECORD (
        operation  VARCHAR2(10),
        record_id  NUMBER,
        old_vals   CLOB,
        new_vals   CLOB
    );
    TYPE t_audit_tbl IS TABLE OF t_audit_row INDEX BY PLS_INTEGER;
    g_audit_rows t_audit_tbl;
    g_idx        PLS_INTEGER := 0;

    AFTER EACH ROW IS
        v_old CLOB;
        v_new CLOB;
    BEGIN
        IF INSERTING THEN
            v_new := 'amount=' || :NEW.amount || ',method=' || :NEW.payment_method || ',status=' || :NEW.status;
            g_idx := g_idx + 1;
            g_audit_rows(g_idx).operation := 'INSERT';
            g_audit_rows(g_idx).record_id := :NEW.payment_id;
            g_audit_rows(g_idx).old_vals  := NULL;
            g_audit_rows(g_idx).new_vals  := v_new;
        ELSIF UPDATING THEN
            v_old := 'amount=' || :OLD.amount || ',status=' || :OLD.status;
            v_new := 'amount=' || :NEW.amount || ',status=' || :NEW.status;
            g_idx := g_idx + 1;
            g_audit_rows(g_idx).operation := 'UPDATE';
            g_audit_rows(g_idx).record_id := :NEW.payment_id;
            g_audit_rows(g_idx).old_vals  := v_old;
            g_audit_rows(g_idx).new_vals  := v_new;
        ELSIF DELETING THEN
            v_old := 'amount=' || :OLD.amount || ',method=' || :OLD.payment_method;
            g_idx := g_idx + 1;
            g_audit_rows(g_idx).operation := 'DELETE';
            g_audit_rows(g_idx).record_id := :OLD.payment_id;
            g_audit_rows(g_idx).old_vals  := v_old;
            g_audit_rows(g_idx).new_vals  := NULL;
        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        FORALL i IN 1..g_idx
            INSERT INTO audit_log (table_name, operation, record_id, old_values, new_values)
            VALUES ('PAYMENTS', g_audit_rows(i).operation,
                    g_audit_rows(i).record_id,
                    g_audit_rows(i).old_vals,
                    g_audit_rows(i).new_vals);
    END AFTER STATEMENT;

END trg_payments_compound;
/

-- -------------------------
-- 6. BEFORE DELETE Trigger: Prevent deletion of active rentals
-- -------------------------
CREATE OR REPLACE TRIGGER trg_rentals_bd
    BEFORE DELETE ON rentals
    FOR EACH ROW
BEGIN
    IF :OLD.status = 'ACTIVE' THEN
        RAISE_APPLICATION_ERROR(-20001,
            'Cannot delete active rental ID: ' || :OLD.rental_id);
    END IF;
END;
/

-- -------------------------
-- 7. Trigger to enforce vehicle availability before rental
-- -------------------------
CREATE OR REPLACE TRIGGER trg_check_vehicle_availability
    BEFORE INSERT ON rentals
    FOR EACH ROW
DECLARE
    v_status VARCHAR2(20);
BEGIN
    SELECT status INTO v_status
      FROM vehicles
     WHERE vehicle_id = :NEW.vehicle_id;

    IF v_status != 'AVAILABLE' THEN
        RAISE_APPLICATION_ERROR(-20002,
            'Vehicle ' || :NEW.vehicle_id || ' is not available. Current status: ' || v_status);
    END IF;
END;
/

-- -------------------------
-- 8. Trigger to validate promo code on reservation
-- -------------------------
CREATE OR REPLACE TRIGGER trg_validate_promo
    BEFORE INSERT OR UPDATE ON reservations
    FOR EACH ROW
    WHEN (NEW.promo_code IS NOT NULL)
DECLARE
    v_count     NUMBER;
    v_active    CHAR(1);
    v_valid_from DATE;
    v_valid_to   DATE;
    v_max_uses   NUMBER;
    v_curr_uses  NUMBER;
BEGIN
    SELECT COUNT(*), MAX(is_active), MAX(valid_from), MAX(valid_to),
           MAX(max_uses), MAX(current_uses)
      INTO v_count, v_active, v_valid_from, v_valid_to, v_max_uses, v_curr_uses
      FROM promo_codes
     WHERE promo_code = :NEW.promo_code;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Invalid promo code: ' || :NEW.promo_code);
    END IF;
    IF v_active = 'N' OR SYSDATE NOT BETWEEN v_valid_from AND v_valid_to THEN
        RAISE_APPLICATION_ERROR(-20004, 'Promo code expired or inactive: ' || :NEW.promo_code);
    END IF;
    IF v_max_uses IS NOT NULL AND v_curr_uses >= v_max_uses THEN
        RAISE_APPLICATION_ERROR(-20005, 'Promo code usage limit reached: ' || :NEW.promo_code);
    END IF;
END;
/

-- -------------------------
-- 9. Maintenance trigger: update vehicle status
-- -------------------------
CREATE OR REPLACE TRIGGER trg_maintenance_ai
    AFTER INSERT ON maintenance
    FOR EACH ROW
    WHEN (NEW.status = 'SCHEDULED' OR NEW.status = 'IN_PROGRESS')
BEGIN
    UPDATE vehicles
       SET status     = 'MAINTENANCE',
           updated_at = SYSTIMESTAMP
     WHERE vehicle_id = :NEW.vehicle_id;
END;
/
