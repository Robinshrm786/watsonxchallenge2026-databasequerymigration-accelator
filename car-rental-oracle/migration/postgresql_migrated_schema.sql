-- =============================================================================
-- CAR RENTAL SYSTEM - POSTGRESQL MIGRATED SCHEMA
-- This file is the PostgreSQL equivalent of Oracle's 01_schema_ddl.sql
-- All Oracle-specific syntax has been translated to PostgreSQL.
-- =============================================================================

-- -------------------------
-- SEQUENCES
-- -------------------------
CREATE SEQUENCE seq_customer_id    START 1001 INCREMENT BY 1 NO CYCLE;
CREATE SEQUENCE seq_vehicle_id     START 2001 INCREMENT BY 1 NO CYCLE;
CREATE SEQUENCE seq_reservation_id START 3001 INCREMENT BY 1 NO CYCLE;
CREATE SEQUENCE seq_rental_id      START 4001 INCREMENT BY 1 NO CYCLE;
CREATE SEQUENCE seq_payment_id     START 5001 INCREMENT BY 1 NO CYCLE;
CREATE SEQUENCE seq_employee_id    START 6001 INCREMENT BY 1 NO CYCLE;
CREATE SEQUENCE seq_location_id    START 7001 INCREMENT BY 1 NO CYCLE;
CREATE SEQUENCE seq_maintenance_id START 8001 INCREMENT BY 1 NO CYCLE;
CREATE SEQUENCE seq_audit_id       START 9001 INCREMENT BY 1 CACHE 20;

-- -------------------------
-- COMPOSITE TYPES (replaces Oracle OBJECT types)
-- -------------------------
CREATE TYPE address_obj AS (
    street      VARCHAR(100),
    city        VARCHAR(60),
    state_code  CHAR(2),
    zip_code    VARCHAR(10),
    country     VARCHAR(50)
);

-- VARRAY(5) OF VARCHAR(20) → TEXT[] with CHECK constraint
-- Oracle: phone_list_t AS VARRAY(5) OF VARCHAR2(20)
-- PostgreSQL: phones TEXT[]

-- Oracle: feature_tbl_t AS TABLE OF VARCHAR2(50) (nested table)
-- PostgreSQL: features TEXT[]

-- -------------------------
-- LOCATIONS
-- -------------------------
CREATE TABLE locations (
    location_id     BIGINT       DEFAULT NEXTVAL('seq_location_id') PRIMARY KEY,
    location_name   VARCHAR(100) NOT NULL,
    location_code   VARCHAR(10)  NOT NULL UNIQUE,
    -- Oracle: address address_obj (object type)
    -- PostgreSQL: composite type column
    address         address_obj,
    phone           VARCHAR(20),
    email           VARCHAR(80),
    operating_hours VARCHAR(100),
    is_active       CHAR(1)      DEFAULT 'Y' CHECK (is_active IN ('Y','N')),
    created_at      TIMESTAMPTZ  DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  DEFAULT NOW()
);

-- -------------------------
-- EMPLOYEES
-- -------------------------
CREATE TABLE employees (
    employee_id  BIGINT       DEFAULT NEXTVAL('seq_employee_id') PRIMARY KEY,
    location_id  BIGINT       REFERENCES locations(location_id),
    first_name   VARCHAR(50)  NOT NULL,
    last_name    VARCHAR(50)  NOT NULL,
    -- Oracle: GENERATED ALWAYS AS (first_name || ' ' || last_name) VIRTUAL
    -- PostgreSQL: generated stored column (PostgreSQL 12+)
    full_name    VARCHAR(101) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
    email        VARCHAR(80)  NOT NULL UNIQUE,
    phone        VARCHAR(20),
    hire_date    DATE         DEFAULT CURRENT_DATE,
    job_title    VARCHAR(50),
    salary       NUMERIC(10,2) CHECK (salary > 0),
    manager_id   BIGINT       REFERENCES employees(employee_id),
    is_active    CHAR(1)      DEFAULT 'Y' CHECK (is_active IN ('Y','N')),
    created_at   TIMESTAMPTZ  DEFAULT NOW()
);

-- -------------------------
-- CUSTOMERS
-- -------------------------
CREATE TABLE customers (
    customer_id    BIGINT       DEFAULT NEXTVAL('seq_customer_id') PRIMARY KEY,
    first_name     VARCHAR(50)  NOT NULL,
    last_name      VARCHAR(50)  NOT NULL,
    full_name      VARCHAR(101) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
    email          VARCHAR(80)  NOT NULL UNIQUE,
    -- Oracle: phones phone_list_t (VARRAY) → PostgreSQL: TEXT array
    phones         TEXT[],
    -- Oracle: address address_obj (nested object)
    -- PostgreSQL: composite type or JSONB
    address        address_obj,
    license_number VARCHAR(30)  NOT NULL UNIQUE,
    license_expiry DATE         NOT NULL,
    date_of_birth  DATE         NOT NULL,
    -- Oracle: GENERATED ALWAYS AS (TRUNC(MONTHS_BETWEEN(SYSDATE,dob)/12)) VIRTUAL
    -- PostgreSQL: cannot reference NOW() in generated column; use a view or function instead
    -- age          INTEGER GENERATED ALWAYS AS (EXTRACT(YEAR FROM AGE(date_of_birth))::INTEGER) STORED,
    loyalty_points INTEGER      DEFAULT 0,
    tier           VARCHAR(10)  DEFAULT 'BRONZE',
    notes          TEXT,
    -- Oracle: id_document BLOB → PostgreSQL: BYTEA
    id_document    BYTEA,
    -- Oracle: profile_xml XMLTYPE → PostgreSQL: XML or JSONB
    profile_xml    JSONB,
    is_active      CHAR(1)      DEFAULT 'Y' CHECK (is_active IN ('Y','N')),
    created_at     TIMESTAMPTZ  DEFAULT NOW(),
    updated_at     TIMESTAMPTZ  DEFAULT NOW()
);

-- -------------------------
-- VEHICLE CATEGORIES
-- -------------------------
CREATE TABLE vehicle_categories (
    -- Oracle: GENERATED ALWAYS AS IDENTITY → PostgreSQL: BIGSERIAL or IDENTITY
    category_id    BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name  VARCHAR(50)  NOT NULL UNIQUE,
    description    VARCHAR(200),
    daily_rate     NUMERIC(8,2) NOT NULL CHECK (daily_rate > 0),
    weekly_rate    NUMERIC(8,2),
    monthly_rate   NUMERIC(8,2),
    deposit_amount NUMERIC(8,2) DEFAULT 500
);

-- -------------------------
-- VEHICLES
-- Note: Oracle partitioning → PostgreSQL declarative partitioning
-- -------------------------
CREATE TABLE vehicles (
    vehicle_id     BIGINT       DEFAULT NEXTVAL('seq_vehicle_id'),
    category_id    BIGINT       NOT NULL REFERENCES vehicle_categories(category_id),
    location_id    BIGINT       REFERENCES locations(location_id),
    make           VARCHAR(50)  NOT NULL,
    model          VARCHAR(50)  NOT NULL,
    model_year     INTEGER      NOT NULL,
    color          VARCHAR(30),
    vin            VARCHAR(17)  NOT NULL UNIQUE,
    license_plate  VARCHAR(15)  NOT NULL UNIQUE,
    mileage        BIGINT       DEFAULT 0,
    fuel_type      VARCHAR(20)  DEFAULT 'GASOLINE'
                                CHECK (fuel_type IN ('GASOLINE','DIESEL','HYBRID','ELECTRIC')),
    transmission   VARCHAR(10)  DEFAULT 'AUTOMATIC'
                                CHECK (transmission IN ('AUTOMATIC','MANUAL')),
    seats          INTEGER      DEFAULT 5,
    status         VARCHAR(20)  DEFAULT 'AVAILABLE'
                                CHECK (status IN ('AVAILABLE','RENTED','MAINTENANCE','RETIRED')),
    -- Oracle: features feature_tbl_t (nested table) → PostgreSQL: TEXT[]
    features       TEXT[],
    daily_override NUMERIC(8,2),
    description    TEXT,
    last_service_date DATE,
    insurance_expiry  DATE,
    is_active      CHAR(1)      DEFAULT 'Y' CHECK (is_active IN ('Y','N')),
    created_at     TIMESTAMPTZ  DEFAULT NOW(),
    updated_at     TIMESTAMPTZ  DEFAULT NOW(),
    CONSTRAINT pk_vehicles PRIMARY KEY (vehicle_id, model_year)
) PARTITION BY RANGE (model_year);

-- PostgreSQL needs explicit partition tables (no INTERVAL keyword)
CREATE TABLE vehicles_legacy  PARTITION OF vehicles FOR VALUES FROM (MINVALUE) TO (2015);
CREATE TABLE vehicles_mid     PARTITION OF vehicles FOR VALUES FROM (2015) TO (2020);
CREATE TABLE vehicles_recent  PARTITION OF vehicles FOR VALUES FROM (2020) TO (2024);
CREATE TABLE vehicles_current PARTITION OF vehicles FOR VALUES FROM (2024) TO (MAXVALUE);

-- -------------------------
-- RESERVATIONS (interval partitioning via pg_partman or explicit)
-- -------------------------
CREATE TABLE reservations (
    reservation_id   BIGINT      DEFAULT NEXTVAL('seq_reservation_id'),
    customer_id      BIGINT      NOT NULL REFERENCES customers(customer_id),
    vehicle_id       BIGINT      NOT NULL,
    pickup_location  BIGINT      NOT NULL REFERENCES locations(location_id),
    dropoff_location BIGINT      NOT NULL REFERENCES locations(location_id),
    pickup_date      DATE        NOT NULL,
    dropoff_date     DATE        NOT NULL,
    status           VARCHAR(20) DEFAULT 'PENDING'
                                 CHECK (status IN ('PENDING','CONFIRMED','CANCELLED','COMPLETED','NO_SHOW')),
    -- Oracle: GENERATED virtual column = dropoff_date - pickup_date
    -- PostgreSQL 12+: GENERATED ALWAYS AS STORED
    total_days       INTEGER     GENERATED ALWAYS AS (dropoff_date - pickup_date) STORED,
    estimated_cost   NUMERIC(10,2),
    promo_code       VARCHAR(20),
    discount_pct     NUMERIC(5,2) DEFAULT 0,
    employee_id      BIGINT      REFERENCES employees(employee_id),
    notes            VARCHAR(500),
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT pk_reservations PRIMARY KEY (reservation_id, pickup_date),
    CONSTRAINT chk_dates CHECK (dropoff_date > pickup_date)
) PARTITION BY RANGE (pickup_date);

CREATE TABLE reservations_default PARTITION OF reservations DEFAULT;

-- -------------------------
-- RENTALS
-- -------------------------
CREATE TABLE rentals (
    rental_id        BIGINT       DEFAULT NEXTVAL('seq_rental_id') PRIMARY KEY,
    reservation_id   BIGINT       REFERENCES reservations(reservation_id),
    customer_id      BIGINT       NOT NULL REFERENCES customers(customer_id),
    vehicle_id       BIGINT       NOT NULL,
    pickup_location  BIGINT       NOT NULL REFERENCES locations(location_id),
    dropoff_location BIGINT       NOT NULL REFERENCES locations(location_id),
    actual_pickup    TIMESTAMPTZ  NOT NULL,
    actual_dropoff   TIMESTAMPTZ,
    odometer_out     BIGINT       NOT NULL,
    odometer_in      BIGINT,
    -- Oracle virtual: odometer_in - odometer_out
    -- PostgreSQL stored generated:
    miles_driven     BIGINT       GENERATED ALWAYS AS (odometer_in - odometer_out) STORED,
    fuel_level_out   INTEGER      DEFAULT 100 CHECK (fuel_level_out BETWEEN 0 AND 100),
    fuel_level_in    INTEGER      CHECK (fuel_level_in BETWEEN 0 AND 100),
    base_charge      NUMERIC(10,2),
    fuel_charge      NUMERIC(8,2) DEFAULT 0,
    damage_charge    NUMERIC(8,2) DEFAULT 0,
    late_fee         NUMERIC(8,2) DEFAULT 0,
    total_charge     NUMERIC(10,2),
    status           VARCHAR(20)  DEFAULT 'ACTIVE'
                                  CHECK (status IN ('ACTIVE','COMPLETED','DISPUTED')),
    employee_out     BIGINT       REFERENCES employees(employee_id),
    employee_in      BIGINT       REFERENCES employees(employee_id),
    damage_notes     TEXT,
    created_at       TIMESTAMPTZ  DEFAULT NOW(),
    updated_at       TIMESTAMPTZ  DEFAULT NOW()
);

-- -------------------------
-- PAYMENTS (LIST partitioning)
-- -------------------------
CREATE TABLE payments (
    payment_id      BIGINT       DEFAULT NEXTVAL('seq_payment_id'),
    rental_id       BIGINT       REFERENCES rentals(rental_id),
    customer_id     BIGINT       NOT NULL REFERENCES customers(customer_id),
    payment_date    TIMESTAMPTZ  DEFAULT NOW(),
    amount          NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    payment_method  VARCHAR(20)  NOT NULL
                                 CHECK (payment_method IN ('CREDIT_CARD','DEBIT_CARD','CASH','BANK_TRANSFER','DIGITAL_WALLET')),
    transaction_ref VARCHAR(50)  UNIQUE,
    status          VARCHAR(20)  DEFAULT 'PENDING'
                                 CHECK (status IN ('PENDING','COMPLETED','FAILED','REFUNDED')),
    currency_code   CHAR(3)      DEFAULT 'USD',
    exchange_rate   NUMERIC(10,6) DEFAULT 1,
    notes           VARCHAR(200),
    created_at      TIMESTAMPTZ  DEFAULT NOW(),
    CONSTRAINT pk_payments PRIMARY KEY (payment_id, payment_method)
) PARTITION BY LIST (payment_method);

CREATE TABLE payments_card  PARTITION OF payments FOR VALUES IN ('CREDIT_CARD','DEBIT_CARD');
CREATE TABLE payments_cash  PARTITION OF payments FOR VALUES IN ('CASH');
CREATE TABLE payments_other PARTITION OF payments FOR VALUES IN ('BANK_TRANSFER','DIGITAL_WALLET');

-- -------------------------
-- MAINTENANCE
-- -------------------------
CREATE TABLE maintenance (
    maintenance_id   BIGINT      DEFAULT NEXTVAL('seq_maintenance_id') PRIMARY KEY,
    vehicle_id       BIGINT      NOT NULL,
    maintenance_type VARCHAR(50) NOT NULL,
    description      VARCHAR(500),
    start_date       DATE        NOT NULL,
    end_date         DATE,
    cost             NUMERIC(10,2),
    vendor           VARCHAR(100),
    technician_notes TEXT,
    status           VARCHAR(20) DEFAULT 'SCHEDULED'
                                 CHECK (status IN ('SCHEDULED','IN_PROGRESS','COMPLETED','CANCELLED')),
    created_by       BIGINT      REFERENCES employees(employee_id),
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- -------------------------
-- AUDIT LOG
-- -------------------------
CREATE TABLE audit_log (
    audit_id   BIGINT      DEFAULT NEXTVAL('seq_audit_id') PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    operation  VARCHAR(10) NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
    record_id  BIGINT      NOT NULL,
    old_values TEXT,
    new_values TEXT,
    -- Oracle: SYS_CONTEXT('USERENV','SESSION_USER') → PostgreSQL: current_user
    changed_by VARCHAR(100) DEFAULT current_user,
    changed_at TIMESTAMPTZ  DEFAULT NOW(),
    -- Oracle: SYS_CONTEXT('USERENV','IP_ADDRESS') → inet_client_addr()
    ip_address INET         DEFAULT inet_client_addr(),
    -- Oracle: SYS_CONTEXT('USERENV','SESSIONID') → pg_backend_pid()
    session_id INTEGER      DEFAULT pg_backend_pid()
);

-- -------------------------
-- PROMO CODES
-- -------------------------
CREATE TABLE promo_codes (
    promo_code    VARCHAR(20)  PRIMARY KEY,
    description   VARCHAR(200),
    discount_type VARCHAR(10)  NOT NULL CHECK (discount_type IN ('PERCENT','FIXED')),
    discount_value NUMERIC(8,2) NOT NULL,
    min_days      INTEGER      DEFAULT 1,
    max_uses      INTEGER,
    current_uses  INTEGER      DEFAULT 0,
    valid_from    DATE         NOT NULL,
    valid_to      DATE         NOT NULL,
    is_active     CHAR(1)      DEFAULT 'Y' CHECK (is_active IN ('Y','N')),
    CONSTRAINT chk_promo_dates CHECK (valid_to > valid_from)
);

-- -------------------------
-- INDEXES
-- -------------------------
CREATE INDEX idx_vehicles_status   ON vehicles(status);
CREATE INDEX idx_vehicles_location ON vehicles(location_id);
CREATE INDEX idx_rentals_customer  ON rentals(customer_id);
CREATE INDEX idx_rentals_vehicle   ON rentals(vehicle_id);
CREATE INDEX idx_payments_rental   ON payments(rental_id);
CREATE INDEX idx_reservations_cust ON reservations(customer_id);

-- Function-based index equivalent in PostgreSQL
CREATE INDEX idx_cust_email_upper ON customers(UPPER(email));
CREATE INDEX idx_cust_name_upper  ON customers((UPPER(last_name) || ', ' || UPPER(first_name)));

-- Oracle invisible index → no direct equivalent; use pg_hint_plan or just skip

-- Oracle bitmap index → PostgreSQL has no bitmap storage indexes
-- Use regular index; planner uses bitmap index scans internally

-- ========================
-- TRIGGERS (PostgreSQL syntax)
-- Replaces Oracle BEFORE INSERT triggers
-- ========================

-- Trigger function: set timestamps on insert
CREATE OR REPLACE FUNCTION trg_set_timestamps()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.created_at := NOW();
    NEW.updated_at := NOW();
    RETURN NEW;
END; $$;

-- Trigger function: update updated_at on row update
CREATE OR REPLACE FUNCTION trg_update_timestamp()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END; $$;

-- Trigger function: auto tier based on loyalty points
CREATE OR REPLACE FUNCTION trg_customers_tier_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.tier := CASE
        WHEN NEW.loyalty_points < 500  THEN 'BRONZE'
        WHEN NEW.loyalty_points < 2000 THEN 'SILVER'
        WHEN NEW.loyalty_points < 5000 THEN 'GOLD'
        ELSE 'PLATINUM'
    END;
    RETURN NEW;
END; $$;

CREATE TRIGGER trg_customers_bi
    BEFORE INSERT ON customers FOR EACH ROW
    EXECUTE FUNCTION trg_customers_tier_fn();

CREATE TRIGGER trg_customers_bu
    BEFORE UPDATE ON customers FOR EACH ROW
    EXECUTE FUNCTION trg_customers_tier_fn();

-- Trigger function: mark vehicle RENTED on rental insert
CREATE OR REPLACE FUNCTION trg_rentals_ai_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE vehicles
       SET status = 'RENTED', updated_at = NOW()
     WHERE vehicle_id = NEW.vehicle_id;
    RETURN NEW;
END; $$;

CREATE TRIGGER trg_rentals_ai
    AFTER INSERT ON rentals FOR EACH ROW
    EXECUTE FUNCTION trg_rentals_ai_fn();

-- Trigger function: complete rental → return vehicle, add loyalty points
CREATE OR REPLACE FUNCTION trg_rentals_au_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = 'COMPLETED' THEN
        UPDATE vehicles
           SET status     = 'AVAILABLE',
               mileage    = COALESCE(NEW.odometer_in, mileage),
               updated_at = NOW()
         WHERE vehicle_id = NEW.vehicle_id;

        UPDATE customers
           SET loyalty_points = loyalty_points + ROUND(COALESCE(NEW.total_charge, 0)),
               updated_at     = NOW()
         WHERE customer_id = NEW.customer_id;
    END IF;
    RETURN NEW;
END; $$;

CREATE TRIGGER trg_rentals_au
    AFTER UPDATE OF status ON rentals FOR EACH ROW
    EXECUTE FUNCTION trg_rentals_au_fn();

-- Audit trigger for payments
CREATE OR REPLACE FUNCTION trg_payments_audit_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log(table_name, operation, record_id, new_values)
        VALUES ('PAYMENTS','INSERT', NEW.payment_id,
                'amount=' || NEW.amount || ',method=' || NEW.payment_method);
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log(table_name, operation, record_id, old_values, new_values)
        VALUES ('PAYMENTS','UPDATE', NEW.payment_id,
                'amount=' || OLD.amount || ',status=' || OLD.status,
                'amount=' || NEW.amount || ',status=' || NEW.status);
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log(table_name, operation, record_id, old_values)
        VALUES ('PAYMENTS','DELETE', OLD.payment_id,
                'amount=' || OLD.amount || ',method=' || OLD.payment_method);
    END IF;
    RETURN NEW;
END; $$;

CREATE TRIGGER trg_payments_audit
    AFTER INSERT OR UPDATE OR DELETE ON payments
    FOR EACH ROW EXECUTE FUNCTION trg_payments_audit_fn();

-- Prevent deletion of active rentals
CREATE OR REPLACE FUNCTION trg_rentals_bd_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status = 'ACTIVE' THEN
        RAISE EXCEPTION 'Cannot delete active rental ID: %', OLD.rental_id
            USING ERRCODE = 'P0001';
    END IF;
    RETURN OLD;
END; $$;

CREATE TRIGGER trg_rentals_bd
    BEFORE DELETE ON rentals FOR EACH ROW
    EXECUTE FUNCTION trg_rentals_bd_fn();

-- ========================
-- VIEWS
-- ========================
CREATE OR REPLACE VIEW v_active_rentals AS
    SELECT r.rental_id,
           r.customer_id,
           c.first_name || ' ' || c.last_name   AS customer_name,
           c.email                               AS customer_email,
           r.vehicle_id,
           v.make || ' ' || v.model              AS vehicle,
           v.license_plate,
           l_pick.location_name                  AS pickup_location_name,
           l_drop.location_name                  AS dropoff_location_name,
           r.actual_pickup,
           r.pickup_location,
           r.dropoff_location,
           -- Oracle: ROUND((SYSTIMESTAMP - r.actual_pickup)*24,1)
           -- PostgreSQL: EXTRACT EPOCH
           ROUND(EXTRACT(EPOCH FROM (NOW() - r.actual_pickup))/3600::NUMERIC, 1) AS hours_out,
           r.odometer_out,
           r.base_charge,
           r.status
      FROM rentals     r
      JOIN customers   c      ON r.customer_id      = c.customer_id
      JOIN vehicles    v      ON r.vehicle_id        = v.vehicle_id
      JOIN locations   l_pick ON r.pickup_location   = l_pick.location_id
      JOIN locations   l_drop ON r.dropoff_location  = l_drop.location_id
     WHERE r.status = 'ACTIVE';

CREATE OR REPLACE VIEW v_vehicle_availability AS
    SELECT v.vehicle_id, v.make, v.model, v.model_year,
           v.license_plate, v.color,
           vc.category_name,
           -- Oracle: NVL(v.daily_override, vc.daily_rate)
           COALESCE(v.daily_override, vc.daily_rate) AS daily_rate,
           l.location_name,
           v.status,
           v.mileage,
           -- Oracle: CASE WHEN v.insurance_expiry < SYSDATE → PostgreSQL: CURRENT_DATE
           CASE WHEN v.insurance_expiry < CURRENT_DATE
                THEN 'EXPIRED' ELSE 'VALID' END  AS insurance_status,
           v.last_service_date
      FROM vehicles v
      JOIN vehicle_categories vc ON v.category_id  = vc.category_id
      LEFT JOIN locations     l  ON v.location_id  = l.location_id
     WHERE v.is_active = 'Y';

-- Revenue view with window functions (ANSI — same syntax both dbs)
CREATE OR REPLACE VIEW v_revenue_dashboard AS
    SELECT TO_CHAR(DATE_TRUNC('month', actual_dropoff),'Mon YYYY') AS month,
           COUNT(*)                                                  AS rentals,
           ROUND(SUM(total_charge),2)                               AS total_revenue,
           ROUND(AVG(total_charge),2)                               AS avg_revenue,
           ROUND(SUM(SUM(total_charge)) OVER (
               ORDER BY DATE_TRUNC('month', actual_dropoff)
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ), 2)                                                     AS running_total,
           ROUND(AVG(SUM(total_charge)) OVER (
               ORDER BY DATE_TRUNC('month', actual_dropoff)
               ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
           ), 2)                                                     AS moving_avg_3m
      FROM rentals
     WHERE status = 'COMPLETED'
     GROUP BY DATE_TRUNC('month', actual_dropoff)
     ORDER BY DATE_TRUNC('month', actual_dropoff);

-- Materialized view (PostgreSQL — no auto-refresh schedule built-in)
CREATE MATERIALIZED VIEW mv_monthly_revenue AS
    SELECT DATE_TRUNC('month', actual_dropoff) AS revenue_month,
           COUNT(*)                             AS rental_count,
           SUM(total_charge)                    AS total_revenue,
           AVG(total_charge)                    AS avg_charge,
           MAX(total_charge)                    AS max_charge,
           MIN(total_charge)                    AS min_charge
      FROM rentals
     WHERE status = 'COMPLETED'
     GROUP BY DATE_TRUNC('month', actual_dropoff);

-- Schedule refresh with pg_cron:
-- SELECT cron.schedule('0 2 * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_revenue');
