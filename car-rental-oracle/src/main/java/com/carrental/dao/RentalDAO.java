package com.carrental.dao;

import com.carrental.model.Rental;
import com.carrental.util.DBConnectionPool;

import java.sql.*;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.logging.Logger;

/**
 * DAO for RENTALS table — migrated from Oracle to PostgreSQL.
 *
 * Key changes from Oracle:
 *  - beginRental: { call car_rental_pkg.begin_rental(?,?,?,?) } CallableStatement
 *    → direct SQL with SELECT FOR UPDATE + INSERT RETURNING rental_id + UPDATE
 *  - completeRental: { call car_rental_pkg.complete_rental(?,?,?,?,?) }
 *    → direct UPDATE SQL; Clob → plain String
 *  - TRUNC(created_at) >= TRUNC(SYSDATE) - 30  → created_at::DATE >= CURRENT_DATE - INTERVAL '30 days'
 *  - ROUND((SYSTIMESTAMP - actual_pickup)*24, 1) → ROUND(EXTRACT(EPOCH FROM (NOW()-actual_pickup))/3600::NUMERIC, 1)
 *  - SYSTIMESTAMP - INTERVAL '3' DAY → NOW() - INTERVAL '3 days'
 *  - NVL(TO_CHAR(TRUNC(...,'MM'),...)) → COALESCE(TO_CHAR(DATE_TRUNC('month',...),...)
 *  - ROLLUP(TRUNC(...,'MM')) → ROLLUP(DATE_TRUNC('month',...))
 */
public class RentalDAO {

    private static final Logger LOG = Logger.getLogger(RentalDAO.class.getName());

    // -----------------------------------------------------------------------
    // BEGIN RENTAL — direct SQL replaces Oracle package procedure call
    // Step 1: SELECT FOR UPDATE (lock reservation)
    // Step 2: INSERT INTO rentals RETURNING rental_id
    // Step 3: UPDATE reservations SET status = 'COMPLETED'
    // -----------------------------------------------------------------------
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
                if (!rs.next()) throw new SQLException("Reservation not found or not in CONFIRMED status");
                vehicleId  = rs.getLong("vehicle_id");
                customerId = rs.getLong("customer_id");
                pickupLoc  = rs.getLong("pickup_location");
                dropoffLoc = rs.getLong("dropoff_location");
            }
            // Step 2: insert rental, get generated ID
            long rentalId;
            try (PreparedStatement ps = conn.prepareStatement(insertSql)) {
                ps.setLong(1, reservationId);
                ps.setLong(2, customerId);
                ps.setLong(3, vehicleId);
                ps.setLong(4, pickupLoc);
                ps.setLong(5, dropoffLoc);
                ps.setLong(6, odometerOut);
                ps.setLong(7, employeeId);
                ResultSet rs = ps.executeQuery();
                if (!rs.next()) throw new SQLException("Insert rental failed, no ID returned.");
                rentalId = rs.getLong(1);
            }
            // Step 3: mark reservation completed
            try (PreparedStatement ps = conn.prepareStatement(updResSql)) {
                ps.setLong(1, reservationId);
                ps.executeUpdate();
            }
            conn.commit();
            LOG.info("Rental started: rentalId=" + rentalId);
            return rentalId;
        } catch (SQLException e) {
            conn.rollback();
            throw e;
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // COMPLETE RENTAL — direct UPDATE replaces Oracle package procedure call
    // Clob → plain String (TEXT in PostgreSQL)
    // -----------------------------------------------------------------------
    public void completeRental(long rentalId, long employeeId, long odometerIn,
                               int fuelLevelIn, String damageNotes) throws SQLException {
        final String sql = """
            UPDATE rentals r
               SET status         = 'COMPLETED',
                   actual_dropoff = NOW(),
                   odometer_in    = ?,
                   fuel_level_in  = ?,
                   base_charge    = (
                       SELECT COALESCE(v.daily_override, vc.daily_rate)
                              * GREATEST(1, CEIL(EXTRACT(EPOCH FROM (NOW() - r2.actual_pickup)) / 86400))
                         FROM rentals r2
                         JOIN vehicles v ON r2.vehicle_id = v.vehicle_id
                         JOIN vehicle_categories vc ON v.category_id = vc.category_id
                        WHERE r2.rental_id = r.rental_id
                   ),
                   fuel_charge    = GREATEST(0, (
                       SELECT (r2.fuel_level_out - ?) * 3
                         FROM rentals r2
                        WHERE r2.rental_id = r.rental_id
                   )),
                   damage_charge  = CASE WHEN ? IS NOT NULL AND LENGTH(?) > 0 THEN 250 ELSE 0 END,
                   total_charge   = base_charge + fuel_charge + damage_charge + COALESCE(late_fee, 0),
                   employee_in    = ?,
                   damage_notes   = ?,
                   updated_at     = NOW()
             WHERE rental_id = ? AND status = 'ACTIVE'
            """;
        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1,   odometerIn);
            ps.setInt(2,    fuelLevelIn);
            ps.setInt(3,    fuelLevelIn);       // fuel_charge subquery
            ps.setString(4, damageNotes);       // damage_charge CASE null check
            ps.setString(5, damageNotes);       // damage_charge LENGTH check
            ps.setLong(6,   employeeId);
            ps.setString(7, damageNotes);       // damage_notes column
            ps.setLong(8,   rentalId);
            int rows = ps.executeUpdate();
            if (rows == 0) throw new SQLException("Active rental not found: " + rentalId);
            conn.commit();
        } catch (SQLException e) {
            conn.rollback();
            throw e;
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // FIND ACTIVE rentals — using view v_active_rentals (unchanged)
    // -----------------------------------------------------------------------
    public List<Rental> findActive() throws SQLException {
        final String sql = """
            SELECT rental_id, customer_id, customer_name, customer_email,
                   vehicle_id, vehicle, license_plate,
                   pickup_location, pickup_location_name,
                   dropoff_location, dropoff_location_name,
                   actual_pickup, hours_out, odometer_out,
                   base_charge, status
              FROM v_active_rentals
             ORDER BY actual_pickup DESC
            """;
        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            return mapActiveView(rs);
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // FIND BY ID — CTE (ANSI SQL, unchanged)
    // -----------------------------------------------------------------------
    public Optional<Rental> findById(long rentalId) throws SQLException {
        final String sql = """
            WITH rental_detail AS (
                SELECT r.*,
                       c.first_name || ' ' || c.last_name AS customer_name,
                       v.make || ' ' || v.model || ' (' || v.model_year || ')' AS vehicle_info,
                       l1.location_name AS pickup_location_name,
                       l2.location_name AS dropoff_location_name
                  FROM rentals   r
                  JOIN customers c  ON r.customer_id       = c.customer_id
                  JOIN vehicles  v  ON r.vehicle_id         = v.vehicle_id
                  JOIN locations l1 ON r.pickup_location    = l1.location_id
                  JOIN locations l2 ON r.dropoff_location   = l2.location_id
                 WHERE r.rental_id = ?
            )
            SELECT * FROM rental_detail
            """;
        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, rentalId);
            List<Rental> list = mapFullResultSet(ps.executeQuery());
            return list.isEmpty() ? Optional.empty() : Optional.of(list.get(0));
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // DASHBOARD QUERY — created_at::DATE cast replaces Oracle TRUNC()
    // -----------------------------------------------------------------------
    public List<Object[]> getDashboardStats() throws SQLException {
        final String sql = """
            SELECT status,
                   COUNT(*)          AS cnt,
                   SUM(total_charge) AS total_revenue,
                   AVG(total_charge) AS avg_charge,
                   MAX(total_charge) AS max_charge
              FROM rentals
             WHERE created_at::DATE >= CURRENT_DATE - INTERVAL '30 days'
             GROUP BY status
             ORDER BY status
            """;
        List<Object[]> rows = new ArrayList<>();
        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                rows.add(new Object[]{
                    rs.getString("status"),
                    rs.getLong("cnt"),
                    rs.getBigDecimal("total_revenue"),
                    rs.getBigDecimal("avg_charge"),
                    rs.getBigDecimal("max_charge")
                });
            }
            return rows;
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // OVERDUE RENTALS — PostgreSQL-compatible timestamp arithmetic
    // -----------------------------------------------------------------------
    public List<Rental> findOverdue() throws SQLException {
        final String sql = """
            SELECT r.rental_id, r.customer_id,
                   c.first_name || ' ' || c.last_name AS customer_name,
                   '' AS customer_email,
                   r.vehicle_id,
                   v.make || ' ' || v.model AS vehicle_info, v.license_plate,
                   r.pickup_location,  l1.location_name AS pickup_location_name,
                   r.dropoff_location, l2.location_name AS dropoff_location_name,
                   r.actual_pickup,
                   NULL AS actual_dropoff,
                   r.odometer_out, NULL AS odometer_in,
                   r.fuel_level_out, NULL AS fuel_level_in,
                   r.base_charge, r.fuel_charge, r.damage_charge, r.late_fee, r.total_charge,
                   r.status, r.employee_out, r.employee_in,
                   ROUND(EXTRACT(EPOCH FROM (NOW() - r.actual_pickup)) / 3600::NUMERIC, 1) AS hours_overdue
              FROM rentals r
              JOIN customers c  ON r.customer_id    = c.customer_id
              JOIN vehicles  v  ON r.vehicle_id      = v.vehicle_id
              JOIN locations l1 ON r.pickup_location = l1.location_id
              JOIN locations l2 ON r.dropoff_location= l2.location_id
             WHERE r.status = 'ACTIVE'
               AND r.actual_pickup < NOW() - INTERVAL '3 days'
             ORDER BY r.actual_pickup ASC
            """;
        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            return mapFullResultSet(rs);
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // REVENUE REPORT — DATE_TRUNC replaces Oracle TRUNC(...,'MM')
    // -----------------------------------------------------------------------
    public List<Object[]> getRevenueReport(LocalDate from, LocalDate to) throws SQLException {
        final String sql = """
            SELECT COALESCE(TO_CHAR(DATE_TRUNC('month', actual_dropoff), 'YYYY-MM'), 'TOTAL') AS period,
                   COUNT(*)                        AS rental_count,
                   ROUND(SUM(total_charge),2)      AS total_revenue,
                   ROUND(AVG(total_charge),2)      AS avg_revenue,
                   ROUND(SUM(base_charge),2)       AS base_rev,
                   ROUND(SUM(fuel_charge),2)       AS fuel_rev,
                   ROUND(SUM(damage_charge),2)     AS damage_rev,
                   ROUND(SUM(late_fee),2)           AS late_fees
              FROM rentals
             WHERE status = 'COMPLETED'
               AND actual_dropoff::DATE BETWEEN ? AND ?
             GROUP BY ROLLUP(DATE_TRUNC('month', actual_dropoff))
             ORDER BY DATE_TRUNC('month', actual_dropoff) NULLS LAST
            """;
        List<Object[]> rows = new ArrayList<>();
        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setDate(1, Date.valueOf(from));
            ps.setDate(2, Date.valueOf(to));
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    rows.add(new Object[]{
                        rs.getString("period"),
                        rs.getLong("rental_count"),
                        rs.getBigDecimal("total_revenue"),
                        rs.getBigDecimal("avg_revenue"),
                        rs.getBigDecimal("base_rev"),
                        rs.getBigDecimal("fuel_rev"),
                        rs.getBigDecimal("damage_rev"),
                        rs.getBigDecimal("late_fees")
                    });
                }
            }
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
        return rows;
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------
    private List<Rental> mapActiveView(ResultSet rs) throws SQLException {
        List<Rental> list = new ArrayList<>();
        while (rs.next()) {
            Rental r = new Rental();
            r.setRentalId(rs.getLong("rental_id"));
            r.setCustomerId(rs.getLong("customer_id"));
            r.setCustomerName(rs.getString("customer_name"));
            r.setVehicleId(rs.getLong("vehicle_id"));
            r.setVehicleInfo(rs.getString("vehicle"));
            r.setPickupLocation(rs.getInt("pickup_location"));
            r.setPickupLocationName(rs.getString("pickup_location_name"));
            r.setDropoffLocation(rs.getInt("dropoff_location"));
            r.setDropoffLocationName(rs.getString("dropoff_location_name"));
            Timestamp ts = rs.getTimestamp("actual_pickup");
            r.setActualPickup(ts != null ? ts.toLocalDateTime() : null);
            r.setOdometerOut(rs.getLong("odometer_out"));
            r.setBaseCharge(rs.getBigDecimal("base_charge"));
            r.setStatus(rs.getString("status"));
            list.add(r);
        }
        return list;
    }

    private List<Rental> mapFullResultSet(ResultSet rs) throws SQLException {
        List<Rental> list = new ArrayList<>();
        while (rs.next()) {
            Rental r = new Rental();
            r.setRentalId(rs.getLong("rental_id"));
            long resId = rs.getLong("reservation_id");
            r.setReservationId(rs.wasNull() ? null : resId);
            r.setCustomerId(rs.getLong("customer_id"));
            r.setCustomerName(rs.getString("customer_name"));
            r.setVehicleId(rs.getLong("vehicle_id"));
            r.setVehicleInfo(rs.getString("vehicle_info"));
            r.setPickupLocation(rs.getInt("pickup_location"));
            r.setPickupLocationName(rs.getString("pickup_location_name"));
            r.setDropoffLocation(rs.getInt("dropoff_location"));
            r.setDropoffLocationName(rs.getString("dropoff_location_name"));
            Timestamp ap = rs.getTimestamp("actual_pickup");
            r.setActualPickup(ap != null ? ap.toLocalDateTime() : null);
            Timestamp ad = rs.getTimestamp("actual_dropoff");
            r.setActualDropoff(ad != null ? ad.toLocalDateTime() : null);
            r.setOdometerOut(rs.getLong("odometer_out"));
            long oi = rs.getLong("odometer_in");
            r.setOdometerIn(rs.wasNull() ? null : oi);
            r.setFuelLevelOut(rs.getInt("fuel_level_out"));
            int fli = rs.getInt("fuel_level_in");
            r.setFuelLevelIn(rs.wasNull() ? null : fli);
            r.setBaseCharge(rs.getBigDecimal("base_charge"));
            r.setFuelCharge(rs.getBigDecimal("fuel_charge"));
            r.setDamageCharge(rs.getBigDecimal("damage_charge"));
            r.setLateFee(rs.getBigDecimal("late_fee"));
            r.setTotalCharge(rs.getBigDecimal("total_charge"));
            r.setStatus(rs.getString("status"));
            r.setEmployeeOut(rs.getLong("employee_out"));
            r.setEmployeeIn(rs.getLong("employee_in"));
            list.add(r);
        }
        return list;
    }
}
