-- =============================================================================
-- CAR RENTAL SYSTEM - ADVANCED ORACLE QUERIES
-- Demonstrates patterns that require migration to PostgreSQL:
--   Analytic/Window Functions, CTEs, CONNECT BY, PIVOT/UNPIVOT,
--   ROWNUM/ROW_NUMBER, DECODE, NVL/NVL2/NULLIF, LISTAGG,
--   MODEL clause, MERGE, Hierarchical Queries, REGEXP, XMLQuery,
--   DBMS_CRYPTO, Flashback, SAMPLE
-- =============================================================================

-- ============================================================
-- SECTION 1: WINDOW / ANALYTIC FUNCTIONS
-- ============================================================

-- 1a. Rank customers by total spend (dense_rank, rank, row_number)
SELECT customer_id,
       customer_name,
       total_spend,
       RANK()       OVER (ORDER BY total_spend DESC) AS spend_rank,
       DENSE_RANK() OVER (ORDER BY total_spend DESC) AS dense_rank,
       ROW_NUMBER() OVER (ORDER BY total_spend DESC) AS rn,
       ROUND(total_spend / SUM(total_spend) OVER () * 100, 2) AS pct_of_total
  FROM (
    SELECT c.customer_id,
           c.first_name || ' ' || c.last_name AS customer_name,
           SUM(r.total_charge)                AS total_spend
      FROM customers c
      JOIN rentals r ON c.customer_id = r.customer_id
     WHERE r.status = 'COMPLETED'
     GROUP BY c.customer_id, c.first_name, c.last_name
  )
 ORDER BY total_spend DESC;

-- 1b. Running totals and moving averages
SELECT rental_id,
       actual_dropoff,
       total_charge,
       SUM(total_charge)   OVER (ORDER BY actual_dropoff
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)  AS running_total,
       AVG(total_charge)   OVER (ORDER BY actual_dropoff
                                 ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)          AS moving_avg_7,
       LAG(total_charge, 1, 0)  OVER (ORDER BY actual_dropoff)                       AS prev_rental_amt,
       LEAD(total_charge, 1, 0) OVER (ORDER BY actual_dropoff)                       AS next_rental_amt,
       FIRST_VALUE(total_charge) OVER (ORDER BY actual_dropoff
                                       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS first_rental,
       LAST_VALUE(total_charge)  OVER (ORDER BY actual_dropoff
                                       ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) AS last_rental,
       NTILE(4)  OVER (ORDER BY total_charge) AS quartile,
       PERCENT_RANK() OVER (ORDER BY total_charge) AS pct_rank,
       CUME_DIST()    OVER (ORDER BY total_charge) AS cum_dist
  FROM rentals
 WHERE status = 'COMPLETED'
 ORDER BY actual_dropoff;

-- 1c. Revenue by location with PARTITION window
SELECT l.location_name,
       TO_CHAR(TRUNC(r.actual_dropoff,'MM'),'YYYY-MM')       AS month,
       SUM(r.total_charge)                                    AS monthly_rev,
       SUM(SUM(r.total_charge)) OVER (
           PARTITION BY l.location_name
           ORDER BY TRUNC(r.actual_dropoff,'MM')
       )                                                      AS cumulative_loc_rev,
       RATIO_TO_REPORT(SUM(r.total_charge)) OVER (
           PARTITION BY TRUNC(r.actual_dropoff,'MM')
       ) * 100                                                AS pct_of_month
  FROM rentals r
  JOIN locations l ON r.pickup_location = l.location_id
 WHERE r.status = 'COMPLETED'
 GROUP BY l.location_name, TRUNC(r.actual_dropoff,'MM')
 ORDER BY l.location_name, month;

-- ============================================================
-- SECTION 2: COMMON TABLE EXPRESSIONS (CTE) / WITH CLAUSE
-- ============================================================

-- 2a. Multi-level CTE: Top vehicles by revenue with category rollup
WITH rental_revenue AS (
    SELECT vehicle_id,
           SUM(total_charge)  AS total_revenue,
           COUNT(*)           AS rental_count,
           AVG(total_charge)  AS avg_charge
      FROM rentals
     WHERE status = 'COMPLETED'
     GROUP BY vehicle_id
),
vehicle_ranked AS (
    SELECT v.vehicle_id, v.make, v.model, v.model_year,
           vc.category_name,
           rr.total_revenue, rr.rental_count, rr.avg_charge,
           RANK() OVER (PARTITION BY vc.category_name ORDER BY rr.total_revenue DESC) AS cat_rank
      FROM vehicles         v
      JOIN vehicle_categories vc ON v.category_id = vc.category_id
      JOIN rental_revenue    rr ON v.vehicle_id   = rr.vehicle_id
),
category_totals AS (
    SELECT category_name,
           SUM(total_revenue)  AS cat_revenue,
           SUM(rental_count)   AS cat_rentals
      FROM vehicle_ranked
     GROUP BY category_name
)
SELECT vr.category_name,
       vr.make || ' ' || vr.model || ' (' || vr.model_year || ')' AS vehicle,
       vr.total_revenue,
       vr.rental_count,
       ROUND(vr.total_revenue / ct.cat_revenue * 100, 2) AS pct_of_category,
       vr.cat_rank
  FROM vehicle_ranked  vr
  JOIN category_totals ct ON vr.category_name = ct.category_name
 WHERE vr.cat_rank <= 3
 ORDER BY vr.category_name, vr.cat_rank;

-- 2b. Recursive CTE: Employee hierarchy (Oracle CONNECT BY alternative)
-- Oracle uses CONNECT BY; this is the ANSI recursive CTE form
WITH emp_hierarchy (employee_id, full_name, manager_id, level_num, path) AS (
    -- Anchor: top-level managers
    SELECT employee_id, first_name || ' ' || last_name, manager_id, 1,
           CAST(first_name || ' ' || last_name AS VARCHAR2(500))
      FROM employees
     WHERE manager_id IS NULL
    UNION ALL
    -- Recursive: employees with a manager
    SELECT e.employee_id, e.first_name || ' ' || e.last_name, e.manager_id,
           h.level_num + 1,
           h.path || ' > ' || e.first_name || ' ' || e.last_name
      FROM employees e
      JOIN emp_hierarchy h ON e.manager_id = h.employee_id
)
SELECT LPAD(' ', (level_num-1)*4, ' ') || full_name AS org_chart,
       level_num,
       path
  FROM emp_hierarchy
 ORDER BY path;

-- ============================================================
-- SECTION 3: ORACLE-SPECIFIC CONNECT BY (Hierarchical)
-- ============================================================

-- 3a. Employee org chart using CONNECT BY
SELECT LEVEL,
       LPAD(' ', LEVEL * 2 - 2) || first_name || ' ' || last_name  AS employee,
       SYS_CONNECT_BY_PATH(first_name || ' ' || last_name, ' / ')  AS full_path,
       CONNECT_BY_ROOT (first_name || ' ' || last_name)             AS root_manager,
       CONNECT_BY_ISLEAF                                             AS is_leaf
  FROM employees
 START WITH manager_id IS NULL
CONNECT BY PRIOR employee_id = manager_id
 ORDER SIBLINGS BY last_name;

-- 3b. Generate a date series for the next 30 days (connect by level trick)
SELECT TRUNC(SYSDATE) + LEVEL - 1 AS rental_date,
       TO_CHAR(TRUNC(SYSDATE) + LEVEL - 1, 'DY')  AS day_name
  FROM dual
CONNECT BY LEVEL <= 30;

-- ============================================================
-- SECTION 4: PIVOT / UNPIVOT
-- ============================================================

-- 4a. PIVOT: Monthly revenue per vehicle category
SELECT *
  FROM (
    SELECT vc.category_name,
           TO_CHAR(TRUNC(r.actual_dropoff,'MM'),'YYYY-MM') AS rev_month,
           r.total_charge
      FROM rentals r
      JOIN vehicles v          ON r.vehicle_id   = v.vehicle_id
      JOIN vehicle_categories vc ON v.category_id = vc.category_id
     WHERE r.status = 'COMPLETED'
  )
  PIVOT (
    ROUND(SUM(total_charge),2) AS revenue,
    COUNT(*)                   AS cnt
    FOR rev_month IN (
        '2024-01' AS jan_2024,
        '2024-02' AS feb_2024,
        '2024-03' AS mar_2024,
        '2024-04' AS apr_2024,
        '2024-05' AS may_2024,
        '2024-06' AS jun_2024
    )
  )
 ORDER BY category_name;

-- 4b. UNPIVOT: Flatten charge columns into rows
SELECT rental_id, charge_type, amount
  FROM rentals
  UNPIVOT (
    amount FOR charge_type IN (
        base_charge   AS 'BASE',
        fuel_charge   AS 'FUEL',
        damage_charge AS 'DAMAGE',
        late_fee      AS 'LATE_FEE'
    )
  )
 WHERE rental_id IN (SELECT rental_id FROM rentals WHERE ROWNUM <= 10)
 ORDER BY rental_id, charge_type;

-- ============================================================
-- SECTION 5: ROWNUM / PAGINATION (Oracle-style)
-- ============================================================

-- 5a. Classic ROWNUM pagination (pre-12c)
SELECT *
  FROM (
    SELECT r.*, ROWNUM AS rn
      FROM (
        SELECT rental_id, customer_id, vehicle_id, total_charge
          FROM rentals
         WHERE status = 'COMPLETED'
         ORDER BY total_charge DESC
      ) r
     WHERE ROWNUM <= 20
  )
 WHERE rn > 10;

-- 5b. Oracle 12c+ FETCH FIRST / OFFSET
SELECT rental_id, customer_id, total_charge
  FROM rentals
 WHERE status = 'COMPLETED'
 ORDER BY total_charge DESC
OFFSET 10 ROWS FETCH NEXT 10 ROWS ONLY;

-- 5c. Top-N with FETCH FIRST WITH TIES
SELECT vehicle_id, make, model, SUM(total_charge) AS revenue
  FROM rentals r JOIN vehicles v USING (vehicle_id)
 WHERE r.status = 'COMPLETED'
 GROUP BY vehicle_id, make, model
 ORDER BY revenue DESC
FETCH FIRST 5 ROWS WITH TIES;

-- ============================================================
-- SECTION 6: DECODE / NVL / NVL2 / NULLIF / COALESCE / CASE
-- ============================================================

SELECT rental_id,
       -- Oracle DECODE (no direct PostgreSQL equivalent — use CASE)
       DECODE(status,
              'ACTIVE',    'On Road',
              'COMPLETED', 'Returned',
              'DISPUTED',  'Under Review',
              'Unknown')                   AS status_label,
       -- NVL (PostgreSQL: COALESCE)
       NVL(total_charge, 0)               AS safe_charge,
       -- NVL2
       NVL2(damage_notes, 'Has Damage', 'No Damage') AS damage_status,
       -- NULLIF
       NULLIF(fuel_charge, 0)             AS fuel_charge_if_any,
       -- COALESCE (ANSI, works in both)
       COALESCE(damage_charge, 0)         AS damage_amt,
       -- CASE searched
       CASE
           WHEN total_charge > 1000 THEN 'Premium'
           WHEN total_charge > 500  THEN 'Standard'
           WHEN total_charge > 0    THEN 'Economy'
           ELSE 'Pending'
       END                                AS rental_tier
  FROM rentals
 ORDER BY rental_id;

-- ============================================================
-- SECTION 7: LISTAGG (PostgreSQL: STRING_AGG)
-- ============================================================

-- 7a. List vehicle features per vehicle
SELECT v.vehicle_id,
       v.make || ' ' || v.model AS vehicle,
       LISTAGG(f.column_value, ', ')
           WITHIN GROUP (ORDER BY f.column_value) AS features
  FROM vehicles v,
       TABLE(v.features) f
 GROUP BY v.vehicle_id, v.make, v.model;

-- 7b. Customers with multiple rentals aggregated
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name AS customer,
       COUNT(r.rental_id)                 AS rental_count,
       LISTAGG(TO_CHAR(r.actual_pickup, 'YYYY-MM-DD'), ' | ')
           WITHIN GROUP (ORDER BY r.actual_pickup) AS rental_dates
  FROM customers c
  JOIN rentals r ON c.customer_id = r.customer_id
 GROUP BY c.customer_id, c.first_name, c.last_name
HAVING COUNT(r.rental_id) > 1;

-- ============================================================
-- SECTION 8: DATE FUNCTIONS (Oracle-specific → PostgreSQL)
-- ============================================================

SELECT rental_id,
       actual_pickup,
       actual_dropoff,
       -- MONTHS_BETWEEN (PostgreSQL: DATE_PART or AGE)
       ROUND(MONTHS_BETWEEN(actual_dropoff, actual_pickup), 2)  AS months_rented,
       -- ADD_MONTHS (PostgreSQL: + INTERVAL)
       ADD_MONTHS(actual_pickup, 1)                             AS one_month_later,
       -- TRUNC date (PostgreSQL: DATE_TRUNC)
       TRUNC(actual_pickup, 'MM')                               AS month_start,
       TRUNC(actual_pickup, 'IW')                               AS week_start,
       -- EXTRACT (ANSI — works both)
       EXTRACT(YEAR  FROM actual_pickup)                        AS rental_year,
       EXTRACT(MONTH FROM actual_pickup)                        AS rental_month,
       -- TO_CHAR date formatting
       TO_CHAR(actual_pickup, 'Day, DD Month YYYY HH24:MI:SS') AS formatted_date,
       -- LAST_DAY (PostgreSQL: DATE_TRUNC('month',d) + INTERVAL '1 month' - 1)
       LAST_DAY(actual_pickup)                                  AS last_of_month,
       -- NEXT_DAY (PostgreSQL: custom function needed)
       NEXT_DAY(actual_pickup, 'MONDAY')                        AS next_monday,
       -- SYSDATE / SYSTIMESTAMP
       SYSDATE                                                   AS now_date,
       SYSTIMESTAMP                                              AS now_ts
  FROM rentals
 WHERE status = 'COMPLETED'
   AND ROWNUM <= 10;

-- ============================================================
-- SECTION 9: STRING FUNCTIONS
-- ============================================================

SELECT customer_id,
       -- SUBSTR (PostgreSQL: SUBSTRING)
       SUBSTR(email, 1, INSTR(email,'@')-1)          AS email_user,
       SUBSTR(email, INSTR(email,'@')+1)             AS email_domain,
       -- INSTR (PostgreSQL: POSITION or STRPOS)
       INSTR(email, '@')                             AS at_position,
       -- TRIM / LTRIM / RTRIM (both)
       TRIM(BOTH ' ' FROM first_name)                AS trimmed_name,
       -- REPLACE (both)
       REPLACE(license_number, '-', '')              AS license_clean,
       -- REGEXP_LIKE (PostgreSQL: ~)
       CASE WHEN REGEXP_LIKE(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
            THEN 'Valid' ELSE 'Invalid' END           AS email_valid,
       -- REGEXP_REPLACE (both)
       REGEXP_REPLACE(license_number, '[^A-Z0-9]','') AS license_alphanum,
       -- REGEXP_SUBSTR
       REGEXP_SUBSTR(email, '[^@]+', 1, 2)           AS domain_part,
       -- INITCAP (both)
       INITCAP(LOWER(first_name))                    AS proper_name,
       -- LPAD / RPAD (both)
       LPAD(customer_id, 8, '0')                     AS padded_id,
       -- WM_CONCAT replaced by LISTAGG; keeping for pattern reference
       -- LENGTH (both)
       LENGTH(email)                                 AS email_len
  FROM customers
 WHERE is_active = 'Y';

-- ============================================================
-- SECTION 10: MODEL CLAUSE (no direct equivalent in PostgreSQL)
-- ============================================================

-- Forecast next 3 months revenue based on last 3 months
SELECT period, revenue
  FROM (
    SELECT TO_CHAR(TRUNC(actual_dropoff,'MM'),'YYYY-MM') AS period,
           ROUND(SUM(total_charge),2)                    AS revenue,
           DENSE_RANK() OVER (ORDER BY TRUNC(actual_dropoff,'MM') DESC) AS rk
      FROM rentals
     WHERE status = 'COMPLETED'
     GROUP BY TRUNC(actual_dropoff,'MM')
  )
 WHERE rk <= 6
 MODEL
    DIMENSION BY (period)
    MEASURES     (revenue)
    RULES (
        revenue['FORECAST_1'] = AVG(revenue)['2024-01','2024-02','2024-03'],
        revenue['FORECAST_2'] = AVG(revenue)['2024-01','2024-02','2024-03'] * 1.05,
        revenue['FORECAST_3'] = AVG(revenue)['2024-01','2024-02','2024-03'] * 1.10
    )
 ORDER BY period;

-- ============================================================
-- SECTION 11: MERGE (UPSERT) — PostgreSQL: INSERT ON CONFLICT
-- ============================================================

MERGE INTO mv_customer_stats dst
USING (
    SELECT r.customer_id,
           COUNT(*)          AS rental_count,
           SUM(total_charge) AS total_spend,
           MAX(actual_pickup) AS last_rental
      FROM rentals r
     WHERE r.status = 'COMPLETED'
     GROUP BY r.customer_id
) src ON (dst.customer_id = src.customer_id)
WHEN MATCHED THEN
    UPDATE SET dst.rental_count = src.rental_count,
               dst.total_spend  = src.total_spend,
               dst.last_rental  = src.last_rental,
               dst.updated_at   = SYSDATE
WHEN NOT MATCHED THEN
    INSERT (customer_id, rental_count, total_spend, last_rental, updated_at)
    VALUES (src.customer_id, src.rental_count, src.total_spend, src.last_rental, SYSDATE);

-- ============================================================
-- SECTION 12: GROUPING SETS / ROLLUP / CUBE
-- ============================================================

-- 12a. ROLLUP: subtotals and grand total
SELECT NVL(l.location_name, 'ALL LOCATIONS')     AS location,
       NVL(vc.category_name, 'ALL CATEGORIES')   AS category,
       TO_CHAR(TRUNC(r.actual_dropoff,'MM'),'YYYY-MM') AS month,
       COUNT(*)                                   AS rentals,
       ROUND(SUM(r.total_charge),2)               AS revenue,
       GROUPING(l.location_name)                  AS is_loc_total,
       GROUPING(vc.category_name)                 AS is_cat_total,
       GROUPING_ID(l.location_name, vc.category_name) AS grouping_level
  FROM rentals     r
  JOIN vehicles    v  ON r.vehicle_id   = v.vehicle_id
  JOIN vehicle_categories vc ON v.category_id = vc.category_id
  JOIN locations   l  ON r.pickup_location = l.location_id
 WHERE r.status = 'COMPLETED'
 GROUP BY ROLLUP(l.location_name, vc.category_name, TRUNC(r.actual_dropoff,'MM'))
 ORDER BY l.location_name NULLS LAST, vc.category_name NULLS LAST, month;

-- 12b. CUBE: All combinations
SELECT NVL(vc.category_name, 'ALL')     AS category,
       NVL(v.fuel_type, 'ALL')          AS fuel_type,
       COUNT(*)                         AS rentals,
       ROUND(SUM(r.total_charge),2)     AS revenue
  FROM rentals r
  JOIN vehicles v ON r.vehicle_id = v.vehicle_id
  JOIN vehicle_categories vc ON v.category_id = vc.category_id
 WHERE r.status = 'COMPLETED'
 GROUP BY CUBE(vc.category_name, v.fuel_type)
 ORDER BY vc.category_name NULLS LAST, v.fuel_type NULLS LAST;

-- ============================================================
-- SECTION 13: SUBQUERY FACTORING & LATERAL JOIN
-- ============================================================

-- 13a. LATERAL (inline view correlated to outer row)
SELECT v.vehicle_id, v.make, v.model,
       latest.rental_id, latest.total_charge, latest.actual_dropoff
  FROM vehicles v,
       LATERAL (
           SELECT rental_id, total_charge, actual_dropoff
             FROM rentals r
            WHERE r.vehicle_id = v.vehicle_id
              AND r.status = 'COMPLETED'
            ORDER BY actual_dropoff DESC
            FETCH FIRST 1 ROW ONLY
       ) latest
 ORDER BY v.vehicle_id;

-- 13b. OUTER APPLY equivalent using LEFT JOIN LATERAL
SELECT v.vehicle_id, v.make, v.model,
       latest.rental_id, latest.total_charge
  FROM vehicles v
  LEFT JOIN LATERAL (
      SELECT rental_id, total_charge
        FROM rentals r
       WHERE r.vehicle_id = v.vehicle_id
         AND r.status = 'COMPLETED'
       ORDER BY actual_dropoff DESC
       FETCH FIRST 1 ROW ONLY
  ) latest ON 1=1
 WHERE v.is_active = 'Y';

-- ============================================================
-- SECTION 14: FLASHBACK QUERY (Oracle-only pattern)
-- ============================================================

-- Query data as of 1 hour ago (no PostgreSQL equivalent — document for migration)
SELECT * FROM rentals AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '1' HOUR)
 WHERE rental_id = 4001;

-- Flashback version query
SELECT rental_id, status, total_charge,
       VERSIONS_STARTTIME, VERSIONS_ENDTIME,
       VERSIONS_OPERATION
  FROM rentals VERSIONS BETWEEN TIMESTAMP
       SYSTIMESTAMP - INTERVAL '24' HOUR AND SYSTIMESTAMP
 WHERE rental_id = 4001
 ORDER BY VERSIONS_STARTTIME;

-- ============================================================
-- SECTION 15: SAMPLE CLAUSE (Oracle-specific)
-- ============================================================

-- Random 10% sample of rentals for analysis
SELECT * FROM rentals SAMPLE(10) WHERE status = 'COMPLETED';

-- Block-level sampling
SELECT * FROM rentals SAMPLE BLOCK(5) WHERE status = 'COMPLETED';

-- ============================================================
-- SECTION 16: XML FUNCTIONS
-- ============================================================

-- Build XML from rental data
SELECT rental_id,
       XMLELEMENT("rental",
           XMLATTRIBUTES(rental_id AS "id"),
           XMLELEMENT("customer",  customer_id),
           XMLELEMENT("vehicle",   vehicle_id),
           XMLELEMENT("amount",    total_charge),
           XMLELEMENT("status",    status)
       ).GETCLOBVAL() AS rental_xml
  FROM rentals
 WHERE ROWNUM <= 5;

-- ============================================================
-- SECTION 17: COMPLEX REPORTING QUERIES
-- ============================================================

-- 17a. Customer Lifetime Value with cohort analysis
WITH first_rental AS (
    SELECT customer_id,
           TRUNC(MIN(actual_pickup),'MM') AS cohort_month
      FROM rentals
     GROUP BY customer_id
),
monthly_activity AS (
    SELECT r.customer_id,
           TRUNC(r.actual_pickup,'MM')     AS activity_month,
           SUM(r.total_charge)             AS monthly_spend
      FROM rentals r
     WHERE r.status = 'COMPLETED'
     GROUP BY r.customer_id, TRUNC(r.actual_pickup,'MM')
)
SELECT f.cohort_month,
       MONTHS_BETWEEN(m.activity_month, f.cohort_month)  AS months_since_first,
       COUNT(DISTINCT m.customer_id)                      AS active_customers,
       ROUND(SUM(m.monthly_spend),2)                      AS cohort_revenue,
       ROUND(AVG(m.monthly_spend),2)                      AS avg_clv
  FROM first_rental    f
  JOIN monthly_activity m ON f.customer_id = m.customer_id
 GROUP BY f.cohort_month, MONTHS_BETWEEN(m.activity_month, f.cohort_month)
 ORDER BY f.cohort_month, months_since_first;

-- 17b. Vehicle maintenance cost vs revenue (profitability)
SELECT v.vehicle_id,
       v.make || ' ' || v.model              AS vehicle,
       v.model_year,
       NVL(rev.total_revenue, 0)             AS total_revenue,
       NVL(mnt.total_maint_cost, 0)          AS total_maint_cost,
       NVL(rev.total_revenue, 0)
           - NVL(mnt.total_maint_cost, 0)    AS net_profit,
       ROUND(NVL(mnt.total_maint_cost, 0)
           / NULLIF(NVL(rev.total_revenue,0),0) * 100, 2) AS cost_ratio_pct
  FROM vehicles v
  LEFT JOIN (
      SELECT vehicle_id, SUM(total_charge) AS total_revenue
        FROM rentals WHERE status = 'COMPLETED'
       GROUP BY vehicle_id
  ) rev ON v.vehicle_id = rev.vehicle_id
  LEFT JOIN (
      SELECT vehicle_id, SUM(cost) AS total_maint_cost
        FROM maintenance WHERE status = 'COMPLETED'
       GROUP BY vehicle_id
  ) mnt ON v.vehicle_id = mnt.vehicle_id
 ORDER BY net_profit DESC;

-- 17c. Day-over-day growth rate using LAG
SELECT period,
       rental_count,
       revenue,
       LAG(revenue) OVER (ORDER BY period)  AS prev_period_revenue,
       ROUND(
           (revenue - LAG(revenue) OVER (ORDER BY period))
           / NULLIF(LAG(revenue) OVER (ORDER BY period), 0) * 100,
       2) AS growth_pct
  FROM (
    SELECT TO_CHAR(TRUNC(actual_dropoff,'MM'),'YYYY-MM') AS period,
           COUNT(*)           AS rental_count,
           SUM(total_charge)  AS revenue
      FROM rentals
     WHERE status = 'COMPLETED'
     GROUP BY TRUNC(actual_dropoff,'MM')
  )
 ORDER BY period;
