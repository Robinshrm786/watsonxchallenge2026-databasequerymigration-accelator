-- =============================================================================
-- ORACLE TO POSTGRESQL MIGRATION GUIDE - QUERY PATTERNS
-- Each section shows the Oracle pattern and its PostgreSQL equivalent
-- =============================================================================

-------------------------------------------------------------------------------
-- 1. SEQUENCES
-------------------------------------------------------------------------------
-- ORACLE:
CREATE SEQUENCE seq_customer_id START WITH 1001 INCREMENT BY 1 NOCACHE NOCYCLE;
-- Using: seq_customer_id.NEXTVAL  /  seq_customer_id.CURRVAL

-- POSTGRESQL:
CREATE SEQUENCE seq_customer_id START WITH 1001 INCREMENT BY 1 NO CYCLE;
-- Using: NEXTVAL('seq_customer_id')  /  CURRVAL('seq_customer_id')
-- Or use IDENTITY columns (PostgreSQL 10+):
-- customer_id BIGINT GENERATED ALWAYS AS IDENTITY

-------------------------------------------------------------------------------
-- 2. AUTO-INCREMENT / IDENTITY
-------------------------------------------------------------------------------
-- ORACLE (12c+):
category_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY

-- POSTGRESQL:
category_id SERIAL PRIMARY KEY
-- or:
category_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY

-------------------------------------------------------------------------------
-- 3. DUAL TABLE
-------------------------------------------------------------------------------
-- ORACLE:
SELECT SYSDATE FROM dual;
SELECT seq_id.NEXTVAL FROM dual;

-- POSTGRESQL (no DUAL):
SELECT NOW();
SELECT NEXTVAL('seq_id');

-------------------------------------------------------------------------------
-- 4. SYSDATE / SYSTIMESTAMP
-------------------------------------------------------------------------------
-- ORACLE:
SYSDATE        -- date + time, no timezone
SYSTIMESTAMP   -- timestamp with timezone

-- POSTGRESQL:
CURRENT_DATE          -- date only
NOW()                 -- timestamp with timezone
CURRENT_TIMESTAMP     -- timestamp with timezone
LOCALTIMESTAMP        -- timestamp without timezone

-------------------------------------------------------------------------------
-- 5. NVL / NVL2
-------------------------------------------------------------------------------
-- ORACLE:
NVL(total_charge, 0)
NVL2(damage_notes, 'Has Damage', 'No Damage')

-- POSTGRESQL:
COALESCE(total_charge, 0)
CASE WHEN damage_notes IS NOT NULL THEN 'Has Damage' ELSE 'No Damage' END

-------------------------------------------------------------------------------
-- 6. DECODE
-------------------------------------------------------------------------------
-- ORACLE:
DECODE(status, 'ACTIVE','On Road', 'COMPLETED','Returned', 'Unknown')

-- POSTGRESQL:
CASE status
    WHEN 'ACTIVE'     THEN 'On Road'
    WHEN 'COMPLETED'  THEN 'Returned'
    ELSE 'Unknown'
END

-------------------------------------------------------------------------------
-- 7. ROWNUM / PAGINATION
-------------------------------------------------------------------------------
-- ORACLE (old style):
SELECT * FROM (SELECT * FROM rentals ORDER BY rental_id) WHERE ROWNUM <= 10;

-- ORACLE (12c+):
SELECT * FROM rentals ORDER BY rental_id FETCH FIRST 10 ROWS ONLY;
SELECT * FROM rentals ORDER BY rental_id OFFSET 10 ROWS FETCH NEXT 10 ROWS ONLY;

-- POSTGRESQL:
SELECT * FROM rentals ORDER BY rental_id LIMIT 10;
SELECT * FROM rentals ORDER BY rental_id LIMIT 10 OFFSET 10;

-------------------------------------------------------------------------------
-- 8. CONNECT BY (Hierarchical Queries)
-------------------------------------------------------------------------------
-- ORACLE:
SELECT LEVEL, employee_id,
       SYS_CONNECT_BY_PATH(last_name, '/') AS path,
       CONNECT_BY_ROOT last_name           AS root
  FROM employees
 START WITH manager_id IS NULL
CONNECT BY PRIOR employee_id = manager_id;

-- POSTGRESQL (recursive CTE):
WITH RECURSIVE emp_tree AS (
    SELECT employee_id, last_name, manager_id, 1 AS lvl,
           last_name::TEXT AS path
      FROM employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.employee_id, e.last_name, e.manager_id, t.lvl + 1,
           t.path || '/' || e.last_name
      FROM employees e JOIN emp_tree t ON e.manager_id = t.employee_id
)
SELECT lvl, employee_id, path FROM emp_tree;

-------------------------------------------------------------------------------
-- 9. ROWID (Oracle physical row address)
-------------------------------------------------------------------------------
-- ORACLE:
SELECT ROWID, rental_id FROM rentals WHERE ROWNUM = 1;

-- POSTGRESQL:
SELECT ctid, rental_id FROM rentals LIMIT 1;
-- Note: ctid is physical; prefer using primary keys

-------------------------------------------------------------------------------
-- 10. LISTAGG
-------------------------------------------------------------------------------
-- ORACLE:
SELECT customer_id,
       LISTAGG(rental_id, ',') WITHIN GROUP (ORDER BY rental_id) AS rentals
  FROM rentals GROUP BY customer_id;

-- POSTGRESQL:
SELECT customer_id,
       STRING_AGG(rental_id::TEXT, ',' ORDER BY rental_id) AS rentals
  FROM rentals GROUP BY customer_id;

-------------------------------------------------------------------------------
-- 11. DATE ARITHMETIC & FUNCTIONS
-------------------------------------------------------------------------------
-- ORACLE                              -- POSTGRESQL
SYSDATE + 7                           -- NOW() + INTERVAL '7 days'
SYSDATE - 30                          -- NOW() - INTERVAL '30 days'
TRUNC(SYSDATE)                        -- DATE_TRUNC('day', NOW())
TRUNC(d, 'MM')                        -- DATE_TRUNC('month', d)
TRUNC(d, 'IW')                        -- DATE_TRUNC('week', d)
TRUNC(d, 'YYYY')                      -- DATE_TRUNC('year', d)
ADD_MONTHS(d, 3)                      -- d + INTERVAL '3 months'
MONTHS_BETWEEN(d1, d2)               -- EXTRACT(EPOCH FROM d1-d2)/2592000 OR
                                      --   (DATE_PART('year',d1) - DATE_PART('year',d2))*12 + ...
LAST_DAY(d)                           -- (DATE_TRUNC('month', d) + INTERVAL '1 month' - INTERVAL '1 day')::DATE
TO_CHAR(d, 'YYYY-MM-DD')             -- TO_CHAR(d, 'YYYY-MM-DD')  [same]
TO_DATE('2024-01-01','YYYY-MM-DD')   -- '2024-01-01'::DATE  or  TO_DATE('2024-01-01','YYYY-MM-DD')
EXTRACT(YEAR FROM d)                  -- EXTRACT(YEAR FROM d)  [same]

-------------------------------------------------------------------------------
-- 12. STRING FUNCTIONS
-------------------------------------------------------------------------------
-- ORACLE                              -- POSTGRESQL
SUBSTR(s, 1, 5)                       -- SUBSTRING(s FROM 1 FOR 5)  or  SUBSTR(s,1,5)
INSTR(s, '@')                         -- POSITION('@' IN s)  or  STRPOS(s,'@')
INSTR(s, '@', 1, 2)                   -- (no direct equiv; use regexp_match or custom func)
LPAD(id, 8, '0')                      -- LPAD(id::TEXT, 8, '0')  [same]
RPAD(s, 10)                           -- RPAD(s, 10)  [same]
LENGTH(s)                             -- LENGTH(s)  [same - returns chars]
LENGTHB(s)                            -- OCTET_LENGTH(s)
REPLACE(s,'a','b')                    -- REPLACE(s,'a','b')  [same]
REGEXP_LIKE(s, 'pat')                 -- s ~ 'pat'  or  regexp_match(s,'pat') IS NOT NULL
REGEXP_REPLACE(s,'pat','rep')         -- REGEXP_REPLACE(s,'pat','rep')  [same]
REGEXP_SUBSTR(s,'pat',1,2)           -- (regexp_match(s,'pat'))[1]
INITCAP(s)                            -- INITCAP(s)  [same]
ASCII(c)                              -- ASCII(c)  [same]
CHR(n)                                -- CHR(n)  [same]
TRIM / LTRIM / RTRIM                  -- TRIM / LTRIM / RTRIM  [same]
UPPER / LOWER                         -- UPPER / LOWER  [same]
CONCAT(a, b)  or  a || b             -- CONCAT(a,b)  or  a || b  [same]
TO_NUMBER(s)                          -- s::NUMERIC  or  CAST(s AS NUMERIC)
TO_CHAR(n, '999,999.00')             -- TO_CHAR(n, '999,999.00')  [same]

-------------------------------------------------------------------------------
-- 13. PIVOT
-------------------------------------------------------------------------------
-- ORACLE:
SELECT * FROM source_table
PIVOT (SUM(amount) FOR month IN ('JAN' AS jan, 'FEB' AS feb, 'MAR' AS mar));

-- POSTGRESQL (crosstab from tablefunc extension):
CREATE EXTENSION IF NOT EXISTS tablefunc;
SELECT * FROM CROSSTAB(
    'SELECT category, month, SUM(amount) FROM t GROUP BY 1,2 ORDER BY 1,2',
    'SELECT DISTINCT month FROM t ORDER BY 1'
) AS pivot_result(category TEXT, jan NUMERIC, feb NUMERIC, mar NUMERIC);
-- Or use conditional aggregation:
SELECT category,
       SUM(CASE WHEN month='JAN' THEN amount END) AS jan,
       SUM(CASE WHEN month='FEB' THEN amount END) AS feb
  FROM t GROUP BY category;

-------------------------------------------------------------------------------
-- 14. MERGE / UPSERT
-------------------------------------------------------------------------------
-- ORACLE:
MERGE INTO target dst USING source src ON (dst.id = src.id)
WHEN MATCHED    THEN UPDATE SET dst.col = src.col
WHEN NOT MATCHED THEN INSERT (id, col) VALUES (src.id, src.col);

-- POSTGRESQL:
INSERT INTO target (id, col) SELECT id, col FROM source
ON CONFLICT (id) DO UPDATE SET col = EXCLUDED.col;
-- PostgreSQL 15+ supports MERGE syntax too:
MERGE INTO target AS dst USING source AS src ON (dst.id = src.id)
WHEN MATCHED    THEN UPDATE SET col = src.col
WHEN NOT MATCHED THEN INSERT (id, col) VALUES (src.id, src.col);

-------------------------------------------------------------------------------
-- 15. OBJECT TYPES / VARRAY / NESTED TABLE
-------------------------------------------------------------------------------
-- ORACLE:
CREATE TYPE address_obj AS OBJECT (street VARCHAR2(100), city VARCHAR2(60));
CREATE TYPE phone_list_t AS VARRAY(5) OF VARCHAR2(20);

-- POSTGRESQL:
CREATE TYPE address_obj AS (street VARCHAR(100), city VARCHAR(60));
-- For arrays:
phones TEXT[]   -- replaces VARRAY
-- Or JSONB for complex objects:
address JSONB

-------------------------------------------------------------------------------
-- 16. XMLTYPE / XML Functions
-------------------------------------------------------------------------------
-- ORACLE:
SELECT XMLELEMENT("rental", XMLATTRIBUTES(rental_id AS "id"), status).GETCLOBVAL() FROM rentals;

-- POSTGRESQL:
SELECT XMLELEMENT(NAME rental, XMLATTRIBUTES(rental_id AS id), status)::TEXT FROM rentals;
-- Or use JSONB for modern APIs:
SELECT jsonb_build_object('id', rental_id, 'status', status) FROM rentals;

-------------------------------------------------------------------------------
-- 17. ANALYTICAL FUNCTIONS (mostly ANSI — same in both)
-------------------------------------------------------------------------------
-- These work in both Oracle and PostgreSQL:
ROW_NUMBER() OVER (...)
RANK()        OVER (...)
DENSE_RANK()  OVER (...)
LAG(col, n)   OVER (...)
LEAD(col, n)  OVER (...)
FIRST_VALUE() OVER (...)
LAST_VALUE()  OVER (...)
NTILE(n)      OVER (...)
SUM(col)      OVER (...)
AVG(col)      OVER (...)
-- Oracle-only → PostgreSQL equivalent:
-- RATIO_TO_REPORT(x) OVER ()  →  x / SUM(x) OVER ()

-------------------------------------------------------------------------------
-- 18. TRIGGERS
-------------------------------------------------------------------------------
-- ORACLE:
CREATE OR REPLACE TRIGGER trg_name BEFORE INSERT ON table FOR EACH ROW BEGIN ... END;

-- POSTGRESQL (two-step):
CREATE OR REPLACE FUNCTION trg_name_fn() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_name BEFORE INSERT ON table
FOR EACH ROW EXECUTE FUNCTION trg_name_fn();

-- Key differences:
-- Oracle: :NEW.col  →  PostgreSQL: NEW.col
-- Oracle: PRAGMA AUTONOMOUS_TRANSACTION  →  PostgreSQL: dblink or separate connection
-- Oracle: RAISE_APPLICATION_ERROR(-20001,'msg')  →  RAISE EXCEPTION 'msg' USING ERRCODE='P0001';

-------------------------------------------------------------------------------
-- 19. PACKAGES → PostgreSQL SCHEMAS + FUNCTIONS
-------------------------------------------------------------------------------
-- Oracle packages become PostgreSQL schemas or function naming conventions
-- ORACLE:
EXECUTE car_rental_pkg.make_reservation(...)

-- POSTGRESQL:
-- Put functions in a dedicated schema:
CREATE SCHEMA car_rental;
CREATE OR REPLACE FUNCTION car_rental.make_reservation(...) RETURNS BIGINT AS $$ ... $$ LANGUAGE plpgsql;

-- Package-level variables → session-level settings or temp tables
-- PRAGMA EXCEPTION_INIT → custom SQLSTATE codes

-------------------------------------------------------------------------------
-- 20. PARTITIONING
-------------------------------------------------------------------------------
-- ORACLE (range partitioning):
CREATE TABLE rentals (...) PARTITION BY RANGE (pickup_date) INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
(PARTITION p1 VALUES LESS THAN (DATE '2024-01-01'));

-- POSTGRESQL (declarative partitioning, v10+):
CREATE TABLE rentals (...) PARTITION BY RANGE (pickup_date);
CREATE TABLE rentals_2024_01 PARTITION OF rentals
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
-- Note: PostgreSQL needs explicit partition tables; no INTERVAL auto-creation
-- Use pg_partman extension for automatic partition management

-------------------------------------------------------------------------------
-- 21. AUTONOMOUS TRANSACTIONS
-------------------------------------------------------------------------------
-- ORACLE:
PRAGMA AUTONOMOUS_TRANSACTION;
COMMIT; -- commits independently of outer transaction

-- POSTGRESQL (no direct equivalent):
-- Option 1: Use dblink to connect back and insert
-- Option 2: Use postgres_fdw
-- Option 3: Restructure to avoid need (most cases)
-- Example with dblink:
PERFORM dblink_exec('dbname=mydb', 'INSERT INTO audit_log VALUES(...)');

-------------------------------------------------------------------------------
-- 22. BULK COLLECT / FORALL
-------------------------------------------------------------------------------
-- ORACLE:
SELECT col BULK COLLECT INTO v_array FROM t WHERE ...;
FORALL i IN 1..v_array.COUNT DELETE FROM t WHERE id = v_array(i);

-- POSTGRESQL:
-- PL/pgSQL uses implicit arrays; bulk operations via plain SQL:
DELETE FROM t WHERE id = ANY(SELECT id FROM t WHERE ...);
-- Or use UNNEST for array-driven DML:
DELETE FROM t WHERE id = ANY(ARRAY(SELECT id FROM staging));

-------------------------------------------------------------------------------
-- 23. MATERIALIZED VIEWS
-------------------------------------------------------------------------------
-- ORACLE (auto-refresh):
CREATE MATERIALIZED VIEW mv_revenue
    REFRESH COMPLETE START WITH SYSDATE NEXT SYSDATE+1
AS SELECT ...;

-- POSTGRESQL:
CREATE MATERIALIZED VIEW mv_revenue AS SELECT ...;
-- Refresh manually:
REFRESH MATERIALIZED VIEW mv_revenue;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_revenue;  -- non-blocking
-- Schedule with pg_cron:
SELECT cron.schedule('0 2 * * *', 'REFRESH MATERIALIZED VIEW mv_revenue');

-------------------------------------------------------------------------------
-- 24. ROWTYPE / %TYPE
-------------------------------------------------------------------------------
-- ORACLE:
v_row rentals%ROWTYPE;
v_id  rentals.rental_id%TYPE;

-- POSTGRESQL (PL/pgSQL):
v_row rentals%ROWTYPE;        -- same!
v_id  rentals.rental_id%TYPE; -- same!

-------------------------------------------------------------------------------
-- 25. EXCEPTION HANDLING
-------------------------------------------------------------------------------
-- ORACLE:
EXCEPTION
    WHEN NO_DATA_FOUND    THEN ...
    WHEN TOO_MANY_ROWS    THEN ...
    WHEN DUP_VAL_ON_INDEX THEN ...
    WHEN OTHERS           THEN DBMS_OUTPUT.PUT_LINE(SQLERRM);

-- POSTGRESQL:
EXCEPTION
    WHEN NO_DATA_FOUND    THEN ...
    WHEN TOO_MANY_ROWS    THEN ...
    WHEN UNIQUE_VIOLATION THEN ...   -- different name!
    WHEN OTHERS           THEN RAISE NOTICE '%', SQLERRM;

-- Oracle DBMS_OUTPUT.PUT_LINE → PostgreSQL RAISE NOTICE '...'

-------------------------------------------------------------------------------
-- 26. INLINE VIEWS vs CTEs
-------------------------------------------------------------------------------
-- ORACLE supports PRAGMA UDF for performance — no equivalent in PostgreSQL
-- Both support WITH (CTE) — use WITH in both for readability
-- ORACLE 19c+ allows WITH FUNCTION (inline PL/SQL) — no equivalent in PostgreSQL
WITH FUNCTION to_usd(v IN NUMBER) RETURN NUMBER IS BEGIN RETURN v * 1.0; END;
SELECT to_usd(total_charge) FROM rentals;

-- POSTGRESQL alternative: standard function
CREATE OR REPLACE FUNCTION to_usd(v NUMERIC) RETURNS NUMERIC AS $$ SELECT v * 1.0; $$ LANGUAGE SQL;

-------------------------------------------------------------------------------
-- 27. FLASHBACK → PostgreSQL temporal
-------------------------------------------------------------------------------
-- ORACLE:
SELECT * FROM rentals AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '1' HOUR);

-- POSTGRESQL: No direct flashback. Alternatives:
-- 1. Temporal tables (via triggers storing history)
-- 2. pg_audit extension
-- 3. Point-in-time recovery from WAL
-- 4. Application-level audit table (recommended)

-------------------------------------------------------------------------------
-- 28. HINTS
-------------------------------------------------------------------------------
-- ORACLE:
SELECT /*+ INDEX(v idx_vehicles_status) PARALLEL(r 4) */ ...

-- POSTGRESQL: No hints. Use:
-- SET enable_seqscan = OFF;  (session-level)
-- CREATE INDEX if missing, then analyze
-- pg_hint_plan extension (third-party)

-------------------------------------------------------------------------------
-- 29. PIPELINED FUNCTIONS
-------------------------------------------------------------------------------
-- ORACLE:
CREATE FUNCTION get_active RETURN t_list PIPELINED IS BEGIN PIPE ROW(v); RETURN; END;
SELECT * FROM TABLE(get_active());

-- POSTGRESQL (SETOF / TABLE returning function):
CREATE OR REPLACE FUNCTION get_active()
RETURNS TABLE(rental_id BIGINT, customer_name TEXT) AS $$
BEGIN
    RETURN QUERY SELECT r.rental_id, c.first_name||' '||c.last_name
                   FROM rentals r JOIN customers c USING(customer_id)
                  WHERE r.status='ACTIVE';
END;
$$ LANGUAGE plpgsql;
SELECT * FROM get_active();

-------------------------------------------------------------------------------
-- 30. CASE SENSITIVITY
-------------------------------------------------------------------------------
-- ORACLE: identifiers are case-INSENSITIVE by default (stored uppercase)
-- POSTGRESQL: identifiers are case-INSENSITIVE by default (stored lowercase)
-- WARNING: Oracle "MyColumn" → PostgreSQL "mycolumn"
-- If Oracle uses double-quoted mixed-case identifiers, must quote in PostgreSQL too
