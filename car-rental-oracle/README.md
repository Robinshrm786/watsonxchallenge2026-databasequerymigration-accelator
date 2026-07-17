# Car Rental Management System (Oracle Edition)

> **Purpose**: Standalone Java web application for car rental management, built on **Oracle Database** with deliberately broad use of Oracle-specific SQL features — enabling comprehensive migration analysis to **PostgreSQL**.

---

## Project Structure

```
car-rental-oracle/
├── pom.xml                               Maven build (WAR)
├── sql/
│   ├── 01_schema_ddl.sql                 Tables, sequences, partitioning, indexes
│   ├── 02_triggers.sql                   9 Oracle triggers (row, compound, INSTEAD OF)
│   ├── 03_packages_and_views.sql         PL/SQL packages, pipelined functions, views, MV
│   ├── 04_advanced_queries.sql           30 advanced Oracle query patterns
│   └── 05_seed_data.sql                  Sample data
├── migration/
│   ├── oracle_to_postgres_guide.sql      30-section side-by-side mapping guide
│   └── postgresql_migrated_schema.sql    PostgreSQL version of the full schema
└── src/main/
    ├── java/com/carrental/
    │   ├── util/
    │   │   ├── DBConnectionPool.java      Manual JDBC pool (Oracle Thin driver)
    │   │   └── JsonUtil.java              Zero-dependency JSON serializer
    │   ├── model/
    │   │   ├── Customer.java
    │   │   ├── Vehicle.java
    │   │   └── Rental.java
    │   ├── dao/
    │   │   ├── CustomerDAO.java           CLOB, generated keys, virtual cols
    │   │   ├── VehicleDAO.java            RETURNING INTO, pipelined fn, FBI index
    │   │   └── RentalDAO.java             Package procedures, REF CURSOR, CTE
    │   └── servlet/
    │       ├── CustomerServlet.java       REST: GET/POST/PUT/DELETE
    │       ├── VehicleServlet.java        REST: GET/POST + utilization
    │       └── RentalServlet.java         REST: begin/complete/report/dashboard
    ├── resources/
    │   └── db.properties                  JDBC connection config
    └── webapp/
        ├── index.html                     Single-page application
        ├── css/main.css                   Responsive UI styles
        └── js/app.js                      Vanilla JS frontend
```

---

## Prerequisites

| Tool | Version |
|------|---------|
| JDK | 17+ |
| Maven | 3.8+ |
| Oracle Database | 19c / 21c / 23ai (or XE) |
| Tomcat | 10.1+ (Jakarta EE 10) |
| OJDBC | ojdbc11.jar (23c) |

---

## Setup

### 1. Create the Oracle schema user
```sql
CREATE USER car_rental IDENTIFIED BY car_rental_pass;
GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE MATERIALIZED VIEW TO car_rental;
GRANT EXECUTE ON DBMS_LOB TO car_rental;
GRANT EXECUTE ON DBMS_CRYPTO TO car_rental;
ALTER USER car_rental DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;
```

### 2. Run SQL scripts in order
```bash
sqlplus car_rental/car_rental_pass@localhost:1521/XEPDB1 @sql/01_schema_ddl.sql
sqlplus car_rental/car_rental_pass@localhost:1521/XEPDB1 @sql/02_triggers.sql
sqlplus car_rental/car_rental_pass@localhost:1521/XEPDB1 @sql/03_packages_and_views.sql
sqlplus car_rental/car_rental_pass@localhost:1521/XEPDB1 @sql/05_seed_data.sql
```

### 3. Configure connection
Edit `src/main/resources/db.properties`:
```properties
db.url=jdbc:oracle:thin:@localhost:1521/XEPDB1
db.user=car_rental
db.password=car_rental_pass
```

### 4. Add ojdbc11.jar to local Maven repo
```bash
mvn install:install-file \
  -Dfile=/path/to/ojdbc11.jar \
  -DgroupId=com.oracle.database.jdbc \
  -DartifactId=ojdbc11 \
  -Dversion=23.3.0.23.09 \
  -Dpackaging=jar
```

### 5. Build and deploy
```bash
mvn clean package
# Deploy target/car-rental.war to Tomcat webapps/
# Then open: http://localhost:8080/car-rental/
```

---

## Oracle SQL Features Used (Migration Targets)

### DDL & Schema Objects
| Feature | File | PostgreSQL Equivalent |
|---------|------|-----------------------|
| `CREATE SEQUENCE` | `01_schema_ddl.sql` | `CREATE SEQUENCE` (same) |
| `GENERATED ALWAYS AS IDENTITY` | `01_schema_ddl.sql` | `BIGSERIAL` or `GENERATED ALWAYS AS IDENTITY` |
| `GENERATED ALWAYS AS (expr) VIRTUAL` | `01_schema_ddl.sql` | `GENERATED ALWAYS AS (expr) STORED` |
| `OBJECT TYPE` | `01_schema_ddl.sql` | `CREATE TYPE AS` (composite) |
| `VARRAY(n) OF type` | `01_schema_ddl.sql` | `TEXT[]` |
| `NESTED TABLE` | `01_schema_ddl.sql` | `TEXT[]` or JSONB |
| `XMLTYPE` | `01_schema_ddl.sql` | `XML` or `JSONB` |
| `BLOB` | `01_schema_ddl.sql` | `BYTEA` |
| `CLOB` | multiple | `TEXT` |
| Partition `RANGE` | `01_schema_ddl.sql` | `PARTITION BY RANGE` (explicit) |
| Partition `LIST` | `01_schema_ddl.sql` | `PARTITION BY LIST` (explicit) |
| Partition `INTERVAL` | `01_schema_ddl.sql` | `pg_partman` extension |
| Function-Based Index | `01_schema_ddl.sql` | Expression index |
| `INVISIBLE INDEX` | `01_schema_ddl.sql` | No equivalent |
| `BITMAP INDEX` | `01_schema_ddl.sql` | No storage-level; planner uses bitmap scans |

### PL/SQL
| Feature | File | PostgreSQL Equivalent |
|---------|------|-----------------------|
| `CREATE PACKAGE` | `03_packages_and_views.sql` | Schema + `plpgsql` functions |
| `PIPELINED FUNCTION` | `03_packages_and_views.sql` | `RETURNS TABLE … RETURN QUERY` |
| `PRAGMA AUTONOMOUS_TRANSACTION` | `03_packages_and_views.sql` | `dblink_exec()` |
| `BULK COLLECT … FORALL` | `03_packages_and_views.sql` | `DELETE … WHERE id = ANY(…)` |
| `REF CURSOR` | `03_packages_and_views.sql` | `REFCURSOR` (supported) |
| `MERGE` | `04_advanced_queries.sql` | `INSERT … ON CONFLICT DO UPDATE` |
| `EXECUTE IMMEDIATE` | DAO layer | `EXECUTE` in PL/pgSQL |

### Triggers
| Type | Oracle | PostgreSQL |
|------|--------|------------|
| `BEFORE INSERT FOR EACH ROW` | Direct | Two-step: function + CREATE TRIGGER |
| `:NEW.col` / `:OLD.col` | `:NEW.col` | `NEW.col` / `OLD.col` |
| `COMPOUND TRIGGER` | Yes | Replicate with per-row + deferred constraint |
| `PRAGMA AUTONOMOUS_TRANSACTION` | Yes | No built-in; use `dblink` |
| `RAISE_APPLICATION_ERROR(-20001, msg)` | Yes | `RAISE EXCEPTION 'msg' USING ERRCODE='P0001'` |

### Query Patterns
| Pattern | Section | PostgreSQL Equivalent |
|---------|---------|----------------------|
| `NVL(x,y)` | `04_advanced_queries.sql` | `COALESCE(x,y)` |
| `NVL2(x,a,b)` | `04_advanced_queries.sql` | `CASE WHEN x IS NOT NULL THEN a ELSE b END` |
| `DECODE(x,v1,r1,…)` | `04_advanced_queries.sql` | `CASE … END` |
| `ROWNUM` | `04_advanced_queries.sql` | `LIMIT` / `ROW_NUMBER() OVER()` |
| `FETCH FIRST n ROWS` | `04_advanced_queries.sql` | `LIMIT n` (same) |
| `CONNECT BY` / `SYS_CONNECT_BY_PATH` | `04_advanced_queries.sql` | `WITH RECURSIVE` CTE |
| `PIVOT` | `04_advanced_queries.sql` | `CROSSTAB()` or conditional agg |
| `UNPIVOT` | `04_advanced_queries.sql` | `UNNEST` or UNION |
| `LISTAGG … WITHIN GROUP` | `04_advanced_queries.sql` | `STRING_AGG(x, ',' ORDER BY …)` |
| `TRUNC(d,'MM')` | `04_advanced_queries.sql` | `DATE_TRUNC('month',d)` |
| `ADD_MONTHS(d,n)` | `04_advanced_queries.sql` | `d + INTERVAL 'n months'` |
| `MONTHS_BETWEEN(a,b)` | `04_advanced_queries.sql` | `EXTRACT(EPOCH FROM a-b)/2592000` |
| `LAST_DAY(d)` | `04_advanced_queries.sql` | `DATE_TRUNC('month',d) + INTERVAL '1 month' - INTERVAL '1 day'` |
| `NEXT_DAY(d,'MON')` | `04_advanced_queries.sql` | Custom function |
| `SYSDATE` / `SYSTIMESTAMP` | everywhere | `CURRENT_DATE` / `NOW()` |
| `REGEXP_LIKE(s,'pat')` | `04_advanced_queries.sql` | `s ~ 'pat'` |
| `INSTR(s,'@')` | `04_advanced_queries.sql` | `POSITION('@' IN s)` |
| `SUBSTR(s,1,5)` | `04_advanced_queries.sql` | `SUBSTRING(s FROM 1 FOR 5)` |
| `MODEL clause` | `04_advanced_queries.sql` | No equivalent; rewrite with CTEs |
| `ROLLUP / CUBE / GROUPING SETS` | `04_advanced_queries.sql` | Same (ANSI SQL) |
| Window functions | `04_advanced_queries.sql` | Same (ANSI SQL) |
| `FLASHBACK QUERY … AS OF` | `04_advanced_queries.sql` | No equivalent; use temporal tables |
| `SAMPLE(n)` | `04_advanced_queries.sql` | `TABLESAMPLE BERNOULLI(n)` |
| `LATERAL` join | `04_advanced_queries.sql` | Same in PostgreSQL |
| `XMLELEMENT` | `04_advanced_queries.sql` | `XMLELEMENT` (same ANSI) |
| `FROM dual` | everywhere | Remove `FROM dual`; select without `FROM` |
| Materialized View auto-refresh | `03_packages_and_views.sql` | `pg_cron` + `REFRESH MATERIALIZED VIEW CONCURRENTLY` |

---

## API Endpoints

### Vehicles
```
GET  /api/vehicles                                   — All available vehicles
GET  /api/vehicles?id={id}                           — Get by ID
GET  /api/vehicles?search={keyword}                  — Search
GET  /api/vehicles?action=utilization&id={id}&from=&to= — Utilization %
POST /api/vehicles                                   — Add vehicle
```

### Customers
```
GET    /api/customers                                — All active customers
GET    /api/customers?id={id}                        — Get by ID
GET    /api/customers?search={keyword}               — Search
GET    /api/customers?id={id}&action=history         — Rental history (analytic SQL)
POST   /api/customers                                — Create
PUT    /api/customers                                — Update
DELETE /api/customers?id={id}                        — Soft delete
```

### Rentals
```
GET  /api/rentals                                    — Active rentals
GET  /api/rentals?id={id}                            — Get by ID
GET  /api/rentals?action=overdue                     — Overdue > 3 days
GET  /api/rentals?action=dashboard                   — 30-day status stats
GET  /api/rentals?action=report&from=&to=            — Revenue with ROLLUP
POST /api/rentals   {action:"begin", reservationId, employeeId, odometerOut}
PUT  /api/rentals   {rentalId, employeeId, odometerIn, fuelLevelIn, damageNotes}
```

---

## PostgreSQL Migration Steps

1. Run `migration/oracle_to_postgres_guide.sql` as a reference during conversion
2. Apply `migration/postgresql_migrated_schema.sql` on the target PostgreSQL server
3. Migrate `sql/03_packages_and_views.sql` functions to `plpgsql` using the guide
4. Replace `ojdbc11.jar` with `postgresql-42.x.x.jar` in `pom.xml`
5. Update `db.properties`: change URL to `jdbc:postgresql://localhost:5432/car_rental`
6. Replace `OracleTypes.CURSOR` with PostgreSQL `CallableStatement` patterns
7. Replace `CLOB` handling with plain `String` / `TEXT` in DAO layer
8. Install `pg_cron` for materialized view auto-refresh scheduling
9. Install `pg_partman` if automatic interval partitioning is needed
10. Run regression tests to verify all 30 query patterns behave identically
