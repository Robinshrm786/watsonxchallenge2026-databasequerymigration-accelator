# Car Rental App — Oracle-to-PostgreSQL Agent Migration Rules
# ============================================================
# PRIMARY KNOWLEDGE SOURCE for the ICA Migration Agent.
# Upload this file as a Knowledge Document in the Agent App.
# Retrieval weight = HIGH  |  Chunking = by-section
# ============================================================

## SCOPE
Source branch : rentalcarapp-oracle
Target branch : rentalcarapp-postgresql

| Layer        | Files to migrate                                                  |
|--------------|-------------------------------------------------------------------|
| Java DAO     | dao/CustomerDAO.java, dao/VehicleDAO.java, dao/RentalDAO.java     |
| Java Util    | util/DBConnectionPool.java                                        |
| Config       | resources/db.properties                                           |
| Build        | pom.xml                                                           |
| SQL DDL      | sql/01_schema_ddl.sql  (target: migration/postgresql_migrated_schema.sql) |
| SQL Packages | sql/03_packages_and_views.sql  (convert to PL/pgSQL functions)    |

---

## PHASE 3 — SQL QUERY MIGRATION RULES

### 3.1 Sequences
| Oracle                        | PostgreSQL                          |
|-------------------------------|-------------------------------------|
| seq_customer_id.NEXTVAL       | NEXTVAL('seq_customer_id')          |
| seq_vehicle_id.NEXTVAL        | NEXTVAL('seq_vehicle_id')           |
| seq_rental_id.NEXTVAL         | NEXTVAL('seq_rental_id')            |
| seq_reservation_id.NEXTVAL    | NEXTVAL('seq_reservation_id')       |
| seq_payment_id.NEXTVAL        | NEXTVAL('seq_payment_id')           |

### 3.2 Date / Timestamp Functions
| Oracle                                              | PostgreSQL                                                        |
|-----------------------------------------------------|-------------------------------------------------------------------|
| SYSDATE                                             | CURRENT_DATE  (date) or NOW() (timestamptz)                       |
| SYSTIMESTAMP                                        | NOW()                                                             |
| TRUNC(SYSDATE)                                      | DATE_TRUNC('day', NOW())::DATE                                    |
| TRUNC(d, 'MM')                                      | DATE_TRUNC('month', d)                                            |
| TRUNC(actual_dropoff,'MM')                          | DATE_TRUNC('month', actual_dropoff)                               |
| ADD_MONTHS(d, n)                                    | d + INTERVAL 'n months'                                           |
| MONTHS_BETWEEN(d1,d2)/12                            | EXTRACT(YEAR FROM AGE(d1, d2))                                    |
| TRUNC(MONTHS_BETWEEN(SYSDATE,date_of_birth)/12)     | EXTRACT(YEAR FROM AGE(NOW(), date_of_birth))::INTEGER             |
| SYSTIMESTAMP - INTERVAL '3' DAY                     | NOW() - INTERVAL '3 days'                                         |
| ROUND((SYSTIMESTAMP - actual_pickup)*24, 1)         | ROUND(EXTRACT(EPOCH FROM (NOW()-actual_pickup))/3600::NUMERIC, 1) |
| CEIL((SYSTIMESTAMP - v_out_ts)*24/24)               | CEIL(EXTRACT(EPOCH FROM (NOW()-v_out_ts))/86400)                  |
| TRUNC(created_at) >= TRUNC(SYSDATE) - 30            | created_at::DATE >= CURRENT_DATE - INTERVAL '30 days'             |

### 3.3 NULL Handling
| Oracle                              | PostgreSQL                                               |
|-------------------------------------|----------------------------------------------------------|
| NVL(x, default)                     | COALESCE(x, default)                                     |
| NVL2(expr, v1, v2)                  | CASE WHEN expr IS NOT NULL THEN v1 ELSE v2 END           |

### 3.4 Aggregation
| Oracle                                              | PostgreSQL                                          |
|-----------------------------------------------------|-----------------------------------------------------|
| LISTAGG(col,',') WITHIN GROUP (ORDER BY col)        | STRING_AGG(col::TEXT, ',' ORDER BY col)             |
| ROLLUP(TRUNC(actual_dropoff,'MM'))                  | ROLLUP(DATE_TRUNC('month', actual_dropoff))         |
| Window functions (ROW_NUMBER, RANK, LAG, LEAD …)    | Same — ANSI SQL (no change needed)                  |

### 3.5 String Functions
| Oracle           | PostgreSQL                              |
|------------------|-----------------------------------------|
| SUBSTR(s,1,5)    | SUBSTRING(s FROM 1 FOR 5)              |
| INSTR(s,'@')     | STRPOS(s,'@')                           |
| TO_NUMBER(s)     | s::NUMERIC                              |
| REGEXP_LIKE(s,p) | s ~ 'p'                                 |
| LENGTHB(s)       | OCTET_LENGTH(s)                         |

### 3.6 DECODE  →  CASE
```sql
-- Oracle:
DECODE(status,'ACTIVE','On Road','COMPLETED','Returned','Unknown')
-- PostgreSQL:
CASE status WHEN 'ACTIVE' THEN 'On Road' WHEN 'COMPLETED' THEN 'Returned' ELSE 'Unknown' END
```

### 3.7 DUAL Table — Remove
```sql
-- Oracle:  SELECT SYSDATE FROM dual
-- Oracle:  SELECT seq.NEXTVAL FROM dual
-- PostgreSQL:  SELECT NOW()
-- PostgreSQL:  SELECT NEXTVAL('seq')    (no FROM clause needed)
```

### 3.8 MERGE → INSERT ON CONFLICT
```sql
-- Oracle:
MERGE INTO promo_codes pc USING (SELECT ? AS pc_code FROM dual) src
  ON (pc.promo_code = src.pc_code)
  WHEN MATCHED THEN UPDATE SET pc.current_uses = pc.current_uses + 1;
-- PostgreSQL:
INSERT INTO promo_codes(promo_code, current_uses) VALUES($1, 1)
ON CONFLICT (promo_code) DO UPDATE SET current_uses = promo_codes.current_uses + 1;
```

### 3.9 CONNECT BY → Recursive CTE
```sql
-- Oracle:
SELECT LEVEL, employee_id FROM employees
  START WITH manager_id IS NULL
  CONNECT BY PRIOR employee_id = manager_id;
-- PostgreSQL:
WITH RECURSIVE emp_tree AS (
  SELECT employee_id, manager_id, 1 AS lvl FROM employees WHERE manager_id IS NULL
  UNION ALL
  SELECT e.employee_id, e.manager_id, t.lvl+1
    FROM employees e JOIN emp_tree t ON e.manager_id = t.employee_id
)
SELECT lvl, employee_id FROM emp_tree;
```

---

## PHASE 3 — JAVA DAO QUERY REWRITES

### CustomerDAO.java

| Method       | Oracle SQL                                          | PostgreSQL SQL                                                  |
|--------------|-----------------------------------------------------|-----------------------------------------------------------------|
| findAll      | TRUNC(MONTHS_BETWEEN(SYSDATE, date_of_birth)/12)   | EXTRACT(YEAR FROM AGE(NOW(), date_of_birth))::INTEGER           |
| findAll      | WHERE (:activeOnly = 0 OR is_active = 'Y')         | WHERE (? = 0 OR is_active = 'Y')   (positional bind)           |
| findById     | TRUNC(MONTHS_BETWEEN(SYSDATE, date_of_birth)/12)   | EXTRACT(YEAR FROM AGE(NOW(), date_of_birth))::INTEGER           |
| insert       | seq_customer_id.NEXTVAL                            | NEXTVAL('seq_customer_id')                                      |
| insert       | ps.setClob(8, clob)                                | ps.setString(8, c.getNotes())   — TEXT, no Clob needed          |
| update       | updated_at = SYSTIMESTAMP                          | updated_at = NOW()                                              |
| softDelete   | updated_at=SYSTIMESTAMP                            | updated_at=NOW()                                                |

### VehicleDAO.java

| Method              | Oracle                                              | PostgreSQL                                                       |
|---------------------|-----------------------------------------------------|------------------------------------------------------------------|
| findAvailable       | NVL(v.daily_override, vc.daily_rate)               | COALESCE(v.daily_override, vc.daily_rate)                        |
| findById            | NVL(v.daily_override, vc.daily_rate)               | COALESCE(v.daily_override, vc.daily_rate)                        |
| search              | NVL(v.daily_override, vc.daily_rate)               | COALESCE(v.daily_override, vc.daily_rate)                        |
| insert              | seq_vehicle_id.NEXTVAL in VALUES                   | NEXTVAL('seq_vehicle_id')                                        |
| insert              | CallableStatement + RETURNING INTO ? (OUT param)   | PreparedStatement + RETURNING vehicle_id, read via executeQuery  |
| insert              | import oracle.jdbc.OracleTypes  (remove)           | Remove import entirely                                           |
| updateStatus        | updated_at = SYSTIMESTAMP                          | updated_at = NOW()                                               |
| getUtilizationRate  | SELECT fn(?,?,?) FROM dual                         | SELECT fn(?,?,?)   (remove FROM dual)                            |
| getMonthlyRevenue   | TABLE(car_rental_pkg.revenue_by_month(?,?))        | Direct GROUP BY ROLLUP query (see full replacement below)        |

**getMonthlyRevenue full replacement:**
```java
final String sql = """
    SELECT COALESCE(TO_CHAR(DATE_TRUNC('month',actual_dropoff),'YYYY-MM'),'TOTAL') AS period_label,
           COUNT(*)          AS rental_count,
           SUM(total_charge) AS total_revenue
      FROM rentals
     WHERE status = 'COMPLETED'
       AND actual_dropoff::DATE BETWEEN ? AND ?
     GROUP BY ROLLUP(DATE_TRUNC('month',actual_dropoff))
     ORDER BY DATE_TRUNC('month',actual_dropoff) NULLS LAST
    """;
```

**insert VehicleDAO full replacement (CallableStatement → PreparedStatement + RETURNING):**
```java
final String sql = """
    INSERT INTO vehicles (
        vehicle_id, category_id, location_id,
        make, model, model_year, color,
        vin, license_plate, mileage, fuel_type, transmission,
        seats, status, daily_override, description,
        last_service_date, insurance_expiry, is_active
    ) VALUES (
        NEXTVAL('seq_vehicle_id'), ?, ?,
        ?, ?, ?, ?,
        ?, ?, ?, ?, ?,
        ?, ?, ?, ?,
        ?, ?, ?
    ) RETURNING vehicle_id
    """;
Connection conn = DBConnectionPool.getInstance().getConnection();
try (PreparedStatement ps = conn.prepareStatement(sql)) {
    // ... bind 18 params ...
    try (ResultSet rs = ps.executeQuery()) {
        if (rs.next()) { long newId = rs.getLong(1); conn.commit(); return newId; }
    }
    conn.rollback();
    throw new SQLException("Insert vehicle failed, no ID returned.");
}
```

### RentalDAO.java

| Method             | Oracle                                                  | PostgreSQL                                                              |
|--------------------|---------------------------------------------------------|-------------------------------------------------------------------------|
| beginRental        | { call car_rental_pkg.begin_rental(?,?,?,?) }          | Direct INSERT with CTE + RETURNING rental_id (see below)               |
| beginRental        | cs.registerOutParameter(4, Types.NUMERIC)              | Remove — use ResultSet from executeQuery()                              |
| completeRental     | { call car_rental_pkg.complete_rental(?,?,?,?,?) }     | Direct UPDATE (see below)                                               |
| completeRental     | conn.createClob() / cs.setClob(5, clob)                | ps.setString(5, damageNotes)   — plain TEXT                             |
| getDashboardStats  | TRUNC(created_at) >= TRUNC(SYSDATE) - 30               | created_at::DATE >= CURRENT_DATE - INTERVAL '30 days'                  |
| findOverdue        | SYSTIMESTAMP - INTERVAL '3' DAY                        | NOW() - INTERVAL '3 days'                                               |
| findOverdue        | ROUND((SYSTIMESTAMP - r.actual_pickup)*24,1)           | ROUND(EXTRACT(EPOCH FROM (NOW()-r.actual_pickup))/3600::NUMERIC,1)     |
| getRevenueReport   | NVL(TO_CHAR(TRUNC(...,'MM'),'YYYY-MM'),'TOTAL')        | COALESCE(TO_CHAR(DATE_TRUNC('month',...),'YYYY-MM'),'TOTAL')           |
| getRevenueReport   | ROLLUP(TRUNC(actual_dropoff,'MM'))                     | ROLLUP(DATE_TRUNC('month', actual_dropoff))                             |
| getRevenueReport   | ORDER BY TRUNC(actual_dropoff,'MM') NULLS LAST         | ORDER BY DATE_TRUNC('month', actual_dropoff) NULLS LAST                |

**beginRental full replacement:**
```java
public long beginRental(long reservationId, long employeeId, long odometerOut) throws SQLException {
    final String lockSql = """
        SELECT vehicle_id, customer_id, pickup_location, dropoff_location
          FROM reservations
         WHERE reservation_id = ? AND status = 'CONFIRMED'
         FOR UPDATE
        """;
    final String insertSql = """
        INSERT INTO rentals (reservation_id, customer_id, vehicle_id,
                             pickup_location, dropoff_location,
                             actual_pickup, odometer_out, employee_out, status)
        VALUES (?, ?, ?, ?, ?, NOW(), ?, ?, 'ACTIVE')
        RETURNING rental_id
        """;
    final String updResSql = "UPDATE reservations SET status='COMPLETED' WHERE reservation_id=?";
    Connection conn = DBConnectionPool.getInstance().getConnection();
    try {
        // Step 1: lock & read reservation
        long vehicleId, customerId, pickupLoc, dropoffLoc;
        try (PreparedStatement ps = conn.prepareStatement(lockSql)) {
            ps.setLong(1, reservationId);
            ResultSet rs = ps.executeQuery();
            if (!rs.next()) throw new SQLException("Reservation not found or not CONFIRMED");
            vehicleId  = rs.getLong("vehicle_id");
            customerId = rs.getLong("customer_id");
            pickupLoc  = rs.getLong("pickup_location");
            dropoffLoc = rs.getLong("dropoff_location");
        }
        // Step 2: insert rental
        long rentalId;
        try (PreparedStatement ps = conn.prepareStatement(insertSql)) {
            ps.setLong(1, reservationId); ps.setLong(2, customerId);
            ps.setLong(3, vehicleId);     ps.setLong(4, pickupLoc);
            ps.setLong(5, dropoffLoc);    ps.setLong(6, odometerOut);
            ps.setLong(7, employeeId);
            ResultSet rs = ps.executeQuery();
            if (!rs.next()) throw new SQLException("Insert rental failed, no ID returned.");
            rentalId = rs.getLong(1);
        }
        // Step 3: update reservation status
        try (PreparedStatement ps = conn.prepareStatement(updResSql)) {
            ps.setLong(1, reservationId);
            ps.executeUpdate();
        }
        conn.commit();
        return rentalId;
    } catch (SQLException e) { conn.rollback(); throw e; }
    finally { DBConnectionPool.getInstance().releaseConnection(conn); }
}
```

**completeRental full replacement:**
```java
public void completeRental(long rentalId, long employeeId, long odometerIn,
                            int fuelLevelIn, String damageNotes) throws SQLException {
    final String sql = """
        UPDATE rentals r
           SET status         = 'COMPLETED',
               actual_dropoff = NOW(),
               odometer_in    = ?,
               fuel_level_in  = ?,
               base_charge    = (
                   SELECT COALESCE(daily_override, vc.daily_rate)
                          * GREATEST(1, CEIL(EXTRACT(EPOCH FROM (NOW()-r2.actual_pickup))/86400))
                     FROM rentals r2
                     JOIN vehicles v ON r2.vehicle_id = v.vehicle_id
                     JOIN vehicle_categories vc ON v.category_id = vc.category_id
                    WHERE r2.rental_id = r.rental_id
               ),
               fuel_charge    = GREATEST(0, (
                   SELECT (r2.fuel_level_out - ?) * 3 FROM rentals r2 WHERE r2.rental_id = r.rental_id
               )),
               damage_charge  = CASE WHEN ? IS NOT NULL AND LENGTH(?) > 0 THEN 250 ELSE 0 END,
               total_charge   = base_charge + fuel_charge + damage_charge + late_fee,
               employee_in    = ?,
               damage_notes   = ?,
               updated_at     = NOW()
         WHERE rental_id = ? AND status = 'ACTIVE'
        """;
    Connection conn = DBConnectionPool.getInstance().getConnection();
    try (PreparedStatement ps = conn.prepareStatement(sql)) {
        ps.setLong(1,   odometerIn);
        ps.setInt(2,    fuelLevelIn);
        ps.setInt(3,    fuelLevelIn);        // fuel_charge subquery
        ps.setString(4, damageNotes);        // damage_charge CASE check
        ps.setString(5, damageNotes);        // damage_charge LENGTH check
        ps.setLong(6,   employeeId);
        ps.setString(7, damageNotes);        // damage_notes column
        ps.setLong(8,   rentalId);
        int rows = ps.executeUpdate();
        if (rows == 0) throw new SQLException("Active rental not found: " + rentalId);
        conn.commit();
    } catch (SQLException e) { conn.rollback(); throw e; }
    finally { DBConnectionPool.getInstance().releaseConnection(conn); }
}
```

---

## PHASE 4 — APPLICATION CONFIGURATION MIGRATION

### 4.1  db.properties  (full replacement)
```properties
# PostgreSQL Database Connection Configuration
# Car Rental Application (migrated from Oracle)

db.url=jdbc:postgresql://localhost:5432/car_rental
db.user=car_rental
db.password=car_rental_pass
db.pool.size=10
db.driver=org.postgresql.Driver
```

### 4.2  pom.xml — dependency changes
Remove both Oracle blocks and the oracle-maven repository. Add PostgreSQL driver:
```xml
<!-- REMOVE these Oracle dependencies -->
<!--
<dependency>
  <groupId>com.oracle.database.jdbc</groupId>
  <artifactId>ojdbc11</artifactId>
  <version>23.3.0.23.09</version>
</dependency>
<dependency>
  <groupId>com.oracle.database.jdbc</groupId>
  <artifactId>ucp</artifactId>
  <version>23.3.0.23.09</version>
</dependency>
-->

<!-- ADD PostgreSQL JDBC driver -->
<dependency>
  <groupId>org.postgresql</groupId>
  <artifactId>postgresql</artifactId>
  <version>42.7.3</version>
</dependency>

<!-- REMOVE Oracle Maven repository block entirely -->
```

### 4.3  DBConnectionPool.java  — driver & property changes
```java
// REMOVE Oracle driver:
// Class.forName("oracle.jdbc.OracleDriver");

// ADD PostgreSQL driver (optional — auto-loaded by JDBC 4+):
Class.forName("org.postgresql.Driver");

// REMOVE Oracle-specific properties:
// connProps.setProperty("oracle.jdbc.implicitStatementCacheSize", "20");
// connProps.setProperty("v$session.program", "CarRentalApp");

// ADD PostgreSQL-compatible properties:
connProps.setProperty("reWriteBatchedInserts", "true");
connProps.setProperty("ApplicationName", "CarRentalApp");
```

### 4.4  VehicleDAO.java  — remove Oracle-only import
```java
// REMOVE this import at top of file:
// import oracle.jdbc.OracleTypes;
```

---

## BRANCH & COMMIT STRATEGY
- Read all files from branch: rentalcarapp-oracle
- Write migrated files to branch: rentalcarapp-postgresql
- One commit per file, message format:
  `feat(migration): Oracle→PostgreSQL <filename>`
- Final summary commit:
  `feat(migration): complete Oracle-to-PostgreSQL migration for car-rental app`
