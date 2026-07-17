-- =============================================================================
-- CAR RENTAL SYSTEM - ORACLE DDL SCHEMA
-- Demonstrates: Sequences, Triggers, Constraints, Partitioning,
--               Object Types, Nested Tables, VARRAYs, XMLType,
--               Virtual Columns, Invisible Indexes, Function-Based Indexes
-- =============================================================================

-- -------------------------
-- TABLESPACES (logical)
-- -------------------------
-- CREATE TABLESPACE car_rental_data DATAFILE 'car_rental.dbf' SIZE 100M AUTOEXTEND ON;
-- CREATE TABLESPACE car_rental_idx  DATAFILE 'car_rental_idx.dbf' SIZE 50M AUTOEXTEND ON;

-- -------------------------
-- SEQUENCES
-- -------------------------
CREATE SEQUENCE seq_customer_id   START WITH 1001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_vehicle_id    START WITH 2001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_reservation_id START WITH 3001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_rental_id     START WITH 4001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_payment_id    START WITH 5001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_employee_id   START WITH 6001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_location_id   START WITH 7001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_maintenance_id START WITH 8001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_audit_id      START WITH 9001 INCREMENT BY 1 CACHE 20;

-- -------------------------
-- OBJECT TYPES
-- -------------------------
CREATE OR REPLACE TYPE address_obj AS OBJECT (
    street      VARCHAR2(100),
    city        VARCHAR2(60),
    state_code  CHAR(2),
    zip_code    VARCHAR2(10),
    country     VARCHAR2(50)
);
/

CREATE OR REPLACE TYPE phone_list_t AS VARRAY(5) OF VARCHAR2(20);
/

CREATE OR REPLACE TYPE feature_tbl_t AS TABLE OF VARCHAR2(50);
/

-- -------------------------
-- LOCATIONS TABLE
-- -------------------------
CREATE TABLE locations (
    location_id     NUMBER(6)    DEFAULT seq_location_id.NEXTVAL PRIMARY KEY,
    location_name   VARCHAR2(100) NOT NULL,
    location_code   VARCHAR2(10)  NOT NULL UNIQUE,
    address         address_obj,
    phone           VARCHAR2(20),
    email           VARCHAR2(80),
    operating_hours VARCHAR2(100),
    is_active       CHAR(1)      DEFAULT 'Y' CHECK (is_active IN ('Y','N')),
    created_at      TIMESTAMP    DEFAULT SYSTIMESTAMP,
    updated_at      TIMESTAMP    DEFAULT SYSTIMESTAMP
) TABLESPACE users;

-- -------------------------
-- EMPLOYEES TABLE
-- -------------------------
CREATE TABLE employees (
    employee_id   NUMBER(6)    DEFAULT seq_employee_id.NEXTVAL PRIMARY KEY,
    location_id   NUMBER(6)    REFERENCES locations(location_id),
    first_name    VARCHAR2(50) NOT NULL,
    last_name     VARCHAR2(50) NOT NULL,
    full_name     VARCHAR2(101) GENERATED ALWAYS AS (first_name || ' ' || last_name) VIRTUAL,
    email         VARCHAR2(80) NOT NULL UNIQUE,
    phone         VARCHAR2(20),
    hire_date     DATE         DEFAULT SYSDATE,
    job_title     VARCHAR2(50),
    salary        NUMBER(10,2) CHECK (salary > 0),
    manager_id    NUMBER(6)    REFERENCES employees(employee_id),
    is_active     CHAR(1)      DEFAULT 'Y' CHECK (is_active IN ('Y','N')),
    created_at    TIMESTAMP    DEFAULT SYSTIMESTAMP
) TABLESPACE users;

-- -------------------------
-- CUSTOMERS TABLE
-- -------------------------
CREATE TABLE customers (
    customer_id    NUMBER(6)    DEFAULT seq_customer_id.NEXTVAL PRIMARY KEY,
    first_name     VARCHAR2(50) NOT NULL,
    last_name      VARCHAR2(50) NOT NULL,
    full_name      VARCHAR2(101) GENERATED ALWAYS AS (first_name || ' ' || last_name) VIRTUAL,
    email          VARCHAR2(80) NOT NULL UNIQUE,
    phones         phone_list_t,
    address        address_obj,
    license_number VARCHAR2(30) NOT NULL UNIQUE,
    license_expiry DATE         NOT NULL,
    date_of_birth  DATE         NOT NULL,
    age            NUMBER       GENERATED ALWAYS AS (TRUNC(MONTHS_BETWEEN(SYSDATE, date_of_birth)/12)) VIRTUAL,
    loyalty_points NUMBER(8)    DEFAULT 0,
    tier           VARCHAR2(10) DEFAULT 'BRONZE',
    notes          CLOB,
    id_document    BLOB,
    profile_xml    XMLTYPE,
    is_active      CHAR(1)      DEFAULT 'Y' CHECK (is_active IN ('Y','N')),
    created_at     TIMESTAMP    DEFAULT SYSTIMESTAMP,
    updated_at     TIMESTAMP    DEFAULT SYSTIMESTAMP
) NESTED TABLE phones STORE AS customers_phones_nt
  TABLESPACE users;

-- -------------------------
-- VEHICLE CATEGORIES
-- -------------------------
CREATE TABLE vehicle_categories (
    category_id   NUMBER(4)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name VARCHAR2(50) NOT NULL UNIQUE,
    description   VARCHAR2(200),
    daily_rate    NUMBER(8,2)  NOT NULL CHECK (daily_rate > 0),
    weekly_rate   NUMBER(8,2),
    monthly_rate  NUMBER(8,2),
    deposit_amount NUMBER(8,2) DEFAULT 500
);

-- -------------------------
-- VEHICLES TABLE (PARTITIONED BY RANGE on model_year)
-- -------------------------
CREATE TABLE vehicles (
    vehicle_id     NUMBER(6)    DEFAULT seq_vehicle_id.NEXTVAL,
    category_id    NUMBER(4)    NOT NULL REFERENCES vehicle_categories(category_id),
    location_id    NUMBER(6)    REFERENCES locations(location_id),
    make           VARCHAR2(50) NOT NULL,
    model          VARCHAR2(50) NOT NULL,
    model_year     NUMBER(4)    NOT NULL,
    color          VARCHAR2(30),
    vin            VARCHAR2(17) NOT NULL UNIQUE,
    license_plate  VARCHAR2(15) NOT NULL UNIQUE,
    mileage        NUMBER(10)   DEFAULT 0,
    fuel_type      VARCHAR2(20) DEFAULT 'GASOLINE'
                                CHECK (fuel_type IN ('GASOLINE','DIESEL','HYBRID','ELECTRIC')),
    transmission   VARCHAR2(10) DEFAULT 'AUTOMATIC'
                                CHECK (transmission IN ('AUTOMATIC','MANUAL')),
    seats          NUMBER(2)    DEFAULT 5,
    status         VARCHAR2(20) DEFAULT 'AVAILABLE'
                                CHECK (status IN ('AVAILABLE','RENTED','MAINTENANCE','RETIRED')),
    features       feature_tbl_t,
    daily_override NUMBER(8,2),
    description    CLOB,
    last_service_date DATE,
    insurance_expiry  DATE,
    is_active      CHAR(1)      DEFAULT 'Y' CHECK (is_active IN ('Y','N')),
    created_at     TIMESTAMP    DEFAULT SYSTIMESTAMP,
    updated_at     TIMESTAMP    DEFAULT SYSTIMESTAMP,
    CONSTRAINT pk_vehicles PRIMARY KEY (vehicle_id)
) NESTED TABLE features STORE AS vehicles_features_nt
  PARTITION BY RANGE (model_year) (
      PARTITION p_legacy  VALUES LESS THAN (2015),
      PARTITION p_mid     VALUES LESS THAN (2020),
      PARTITION p_recent  VALUES LESS THAN (2024),
      PARTITION p_current VALUES LESS THAN (MAXVALUE)
  )
  TABLESPACE users;

-- -------------------------
-- RESERVATIONS TABLE (PARTITIONED BY RANGE on pickup_date)
-- -------------------------
CREATE TABLE reservations (
    reservation_id   NUMBER(8)   DEFAULT seq_reservation_id.NEXTVAL,
    customer_id      NUMBER(6)   NOT NULL REFERENCES customers(customer_id),
    vehicle_id       NUMBER(6)   NOT NULL,
    pickup_location  NUMBER(6)   NOT NULL REFERENCES locations(location_id),
    dropoff_location NUMBER(6)   NOT NULL REFERENCES locations(location_id),
    pickup_date      DATE        NOT NULL,
    dropoff_date     DATE        NOT NULL,
    status           VARCHAR2(20) DEFAULT 'PENDING'
                                  CHECK (status IN ('PENDING','CONFIRMED','CANCELLED','COMPLETED','NO_SHOW')),
    total_days       NUMBER(4)   GENERATED ALWAYS AS (dropoff_date - pickup_date) VIRTUAL,
    estimated_cost   NUMBER(10,2),
    promo_code       VARCHAR2(20),
    discount_pct     NUMBER(5,2) DEFAULT 0,
    employee_id      NUMBER(6)   REFERENCES employees(employee_id),
    notes            VARCHAR2(500),
    created_at       TIMESTAMP   DEFAULT SYSTIMESTAMP,
    updated_at       TIMESTAMP   DEFAULT SYSTIMESTAMP,
    CONSTRAINT pk_reservations PRIMARY KEY (reservation_id),
    CONSTRAINT chk_dates CHECK (dropoff_date > pickup_date)
) PARTITION BY RANGE (pickup_date) INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
  (PARTITION p_res_before_2024 VALUES LESS THAN (DATE '2024-01-01'))
  TABLESPACE users;

-- -------------------------
-- RENTALS TABLE
-- -------------------------
CREATE TABLE rentals (
    rental_id        NUMBER(8)    DEFAULT seq_rental_id.NEXTVAL,
    reservation_id   NUMBER(8)    REFERENCES reservations(reservation_id),
    customer_id      NUMBER(6)    NOT NULL REFERENCES customers(customer_id),
    vehicle_id       NUMBER(6)    NOT NULL,
    pickup_location  NUMBER(6)    NOT NULL REFERENCES locations(location_id),
    dropoff_location NUMBER(6)    NOT NULL REFERENCES locations(location_id),
    actual_pickup    TIMESTAMP    NOT NULL,
    actual_dropoff   TIMESTAMP,
    odometer_out     NUMBER(10)   NOT NULL,
    odometer_in      NUMBER(10),
    miles_driven     NUMBER(8)    GENERATED ALWAYS AS (odometer_in - odometer_out) VIRTUAL,
    fuel_level_out   NUMBER(3)    DEFAULT 100 CHECK (fuel_level_out BETWEEN 0 AND 100),
    fuel_level_in    NUMBER(3)    CHECK (fuel_level_in BETWEEN 0 AND 100),
    base_charge      NUMBER(10,2),
    fuel_charge      NUMBER(8,2)  DEFAULT 0,
    damage_charge    NUMBER(8,2)  DEFAULT 0,
    late_fee         NUMBER(8,2)  DEFAULT 0,
    total_charge     NUMBER(10,2),
    status           VARCHAR2(20) DEFAULT 'ACTIVE'
                                  CHECK (status IN ('ACTIVE','COMPLETED','DISPUTED')),
    employee_out     NUMBER(6)    REFERENCES employees(employee_id),
    employee_in      NUMBER(6)    REFERENCES employees(employee_id),
    damage_notes     CLOB,
    created_at       TIMESTAMP    DEFAULT SYSTIMESTAMP,
    updated_at       TIMESTAMP    DEFAULT SYSTIMESTAMP,
    CONSTRAINT pk_rentals PRIMARY KEY (rental_id)
) TABLESPACE users;

-- -------------------------
-- PAYMENTS TABLE (PARTITIONED BY LIST on payment_method)
-- -------------------------
CREATE TABLE payments (
    payment_id     NUMBER(8)    DEFAULT seq_payment_id.NEXTVAL,
    rental_id      NUMBER(8)    REFERENCES rentals(rental_id),
    customer_id    NUMBER(6)    NOT NULL REFERENCES customers(customer_id),
    payment_date   TIMESTAMP    DEFAULT SYSTIMESTAMP,
    amount         NUMBER(10,2) NOT NULL CHECK (amount > 0),
    payment_method VARCHAR2(20) NOT NULL
                               CHECK (payment_method IN ('CREDIT_CARD','DEBIT_CARD','CASH','BANK_TRANSFER','DIGITAL_WALLET')),
    transaction_ref VARCHAR2(50) UNIQUE,
    status          VARCHAR2(20) DEFAULT 'PENDING'
                                 CHECK (status IN ('PENDING','COMPLETED','FAILED','REFUNDED')),
    currency_code   CHAR(3)     DEFAULT 'USD',
    exchange_rate   NUMBER(10,6) DEFAULT 1,
    notes           VARCHAR2(200),
    created_at      TIMESTAMP   DEFAULT SYSTIMESTAMP,
    CONSTRAINT pk_payments PRIMARY KEY (payment_id)
) PARTITION BY LIST (payment_method) (
    PARTITION p_pay_card   VALUES ('CREDIT_CARD','DEBIT_CARD'),
    PARTITION p_pay_cash   VALUES ('CASH'),
    PARTITION p_pay_other  VALUES ('BANK_TRANSFER','DIGITAL_WALLET')
) TABLESPACE users;

-- -------------------------
-- MAINTENANCE TABLE
-- -------------------------
CREATE TABLE maintenance (
    maintenance_id  NUMBER(8)   DEFAULT seq_maintenance_id.NEXTVAL PRIMARY KEY,
    vehicle_id      NUMBER(6)   NOT NULL,
    maintenance_type VARCHAR2(50) NOT NULL,
    description     VARCHAR2(500),
    start_date      DATE        NOT NULL,
    end_date        DATE,
    cost            NUMBER(10,2),
    vendor          VARCHAR2(100),
    technician_notes CLOB,
    status          VARCHAR2(20) DEFAULT 'SCHEDULED'
                                 CHECK (status IN ('SCHEDULED','IN_PROGRESS','COMPLETED','CANCELLED')),
    created_by      NUMBER(6)   REFERENCES employees(employee_id),
    created_at      TIMESTAMP   DEFAULT SYSTIMESTAMP
);

-- -------------------------
-- AUDIT LOG TABLE
-- -------------------------
CREATE TABLE audit_log (
    audit_id      NUMBER(10)   DEFAULT seq_audit_id.NEXTVAL PRIMARY KEY,
    table_name    VARCHAR2(50) NOT NULL,
    operation     VARCHAR2(10) NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
    record_id     NUMBER(10)   NOT NULL,
    old_values    CLOB,
    new_values    CLOB,
    changed_by    VARCHAR2(100) DEFAULT SYS_CONTEXT('USERENV','SESSION_USER'),
    changed_at    TIMESTAMP    DEFAULT SYSTIMESTAMP,
    ip_address    VARCHAR2(45) DEFAULT SYS_CONTEXT('USERENV','IP_ADDRESS'),
    session_id    NUMBER       DEFAULT SYS_CONTEXT('USERENV','SESSIONID')
) TABLESPACE users;

-- -------------------------
-- PROMO CODES TABLE
-- -------------------------
CREATE TABLE promo_codes (
    promo_code    VARCHAR2(20)  PRIMARY KEY,
    description   VARCHAR2(200),
    discount_type VARCHAR2(10)  NOT NULL CHECK (discount_type IN ('PERCENT','FIXED')),
    discount_value NUMBER(8,2)  NOT NULL,
    min_days      NUMBER(3)    DEFAULT 1,
    max_uses      NUMBER(6),
    current_uses  NUMBER(6)    DEFAULT 0,
    valid_from    DATE         NOT NULL,
    valid_to      DATE         NOT NULL,
    is_active     CHAR(1)      DEFAULT 'Y' CHECK (is_active IN ('Y','N')),
    CONSTRAINT chk_promo_dates CHECK (valid_to > valid_from)
);

-- -------------------------
-- INDEXES (including function-based and invisible)
-- -------------------------
-- Standard B-Tree
CREATE INDEX idx_vehicles_status   ON vehicles(status) LOCAL;
CREATE INDEX idx_vehicles_location ON vehicles(location_id) LOCAL;
CREATE INDEX idx_rentals_customer  ON rentals(customer_id);
CREATE INDEX idx_rentals_vehicle   ON rentals(vehicle_id);
CREATE INDEX idx_payments_rental   ON payments(rental_id);
CREATE INDEX idx_reservations_cust ON reservations(customer_id) LOCAL;

-- Function-Based Index
CREATE INDEX idx_cust_email_upper ON customers(UPPER(email));
CREATE INDEX idx_cust_name_upper  ON customers(UPPER(last_name) || ', ' || UPPER(first_name));

-- Invisible Index (won't be used by optimizer unless ALTER SESSION SET use_invisible_indexes=TRUE)
CREATE INDEX idx_vehicles_vin INVISIBLE ON vehicles(vin) LOCAL;

-- Bitmap Index (suitable for low-cardinality columns in data warehouse scenarios)
-- Note: In OLTP use only if data is read-heavy and rarely updated
CREATE BITMAP INDEX idx_vehicles_fuel_bmp ON vehicles(fuel_type) LOCAL;
CREATE BITMAP INDEX idx_vehicles_trans_bmp ON vehicles(transmission) LOCAL;
