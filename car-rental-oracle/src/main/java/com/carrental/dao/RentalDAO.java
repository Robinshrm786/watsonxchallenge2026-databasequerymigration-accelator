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
 * DAO for RENTALS table.
 *
 * Oracle patterns:
 *  - CallableStatement calling package procedures (car_rental_pkg)
 *  - REF CURSOR output parameter (OracleTypes.CURSOR)
 *  - EXECUTE IMMEDIATE via Java dynamic SQL building
 *  - Analytic functions in SELECT
 *  - CTE (WITH clause) queries
 */
public class RentalDAO {

    private static final Logger LOG = Logger.getLogger(RentalDAO.class.getName());

    // -----------------------------------------------------------------------
    // BEGIN RENTAL — calls Oracle package procedure with OUT parameter
    // Oracle CallableStatement: {call pkg.proc(?,?,?,?)}
    // -----------------------------------------------------------------------
    public long beginRental(long reservationId, long employeeId, long odometerOut) throws SQLException {
        // Oracle package procedure call syntax
        final String call = "{ call car_rental_pkg.begin_rental(?, ?, ?, ?) }";
        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (CallableStatement cs = conn.prepareCall(call)) {
            cs.setLong(1, reservationId);
            cs.setLong(2, employeeId);
            cs.setLong(3, odometerOut);
            cs.registerOutParameter(4, Types.NUMERIC);  // OUT p_rental_id
            cs.execute();
            long rentalId = cs.getLong(4);
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
    // COMPLETE RENTAL — calls Oracle package procedure
    // -----------------------------------------------------------------------
    public void completeRental(long rentalId, long employeeId, long odometerIn,
                               int fuelLevelIn, String damageNotes) throws SQLException {
        final String call = "{ call car_rental_pkg.complete_rental(?, ?, ?, ?, ?) }";
        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (CallableStatement cs = conn.prepareCall(call)) {
            cs.setLong(1, rentalId);
            cs.setLong(2, employeeId);
            cs.setLong(3, odometerIn);
            cs.setInt(4, fuelLevelIn);
            if (damageNotes != null && !damageNotes.isBlank()) {
                Clob clob = conn.createClob();
                clob.setString(1, damageNotes);
                cs.setClob(5, clob);
            } else {
                cs.setNull(5, Types.CLOB);
            }
            cs.execute();
            conn.commit();
        } catch (SQLException e) {
            conn.rollback();
            throw e;
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // FIND ACTIVE rentals — using Oracle view v_active_rentals
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
    // FIND BY ID — uses CTE for clean read
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
    // DASHBOARD QUERY — uses analytic functions
    // -----------------------------------------------------------------------
    public List<Object[]> getDashboardStats() throws SQLException {
        final String sql = """
            SELECT status,
                   COUNT(*)          AS cnt,
                   SUM(total_charge) AS total_revenue,
                   AVG(total_charge) AS avg_charge,
                   MAX(total_charge) AS max_charge
              FROM rentals
             WHERE TRUNC(created_at) >= TRUNC(SYSDATE) - 30
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
    // OVERDUE RENTALS — using EXTRACT and INTERVAL arithmetic
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
                   ROUND((SYSTIMESTAMP - r.actual_pickup) * 24, 1) AS hours_overdue
              FROM rentals r
              JOIN customers c  ON r.customer_id    = c.customer_id
              JOIN vehicles  v  ON r.vehicle_id      = v.vehicle_id
              JOIN locations l1 ON r.pickup_location = l1.location_id
              JOIN locations l2 ON r.dropoff_location= l2.location_id
             WHERE r.status = 'ACTIVE'
               AND r.actual_pickup < SYSTIMESTAMP - INTERVAL '3' DAY
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
    // REVENUE REPORT — uses materialized view + ROLLUP
    // -----------------------------------------------------------------------
    public List<Object[]> getRevenueReport(LocalDate from, LocalDate to) throws SQLException {
        final String sql = """
            SELECT NVL(TO_CHAR(TRUNC(actual_dropoff,'MM'),'YYYY-MM'), 'TOTAL') AS period,
                   COUNT(*)                        AS rental_count,
                   ROUND(SUM(total_charge),2)      AS total_revenue,
                   ROUND(AVG(total_charge),2)      AS avg_revenue,
                   ROUND(SUM(base_charge),2)       AS base_rev,
                   ROUND(SUM(fuel_charge),2)       AS fuel_rev,
                   ROUND(SUM(damage_charge),2)     AS damage_rev,
                   ROUND(SUM(late_fee),2)           AS late_fees
              FROM rentals
             WHERE status = 'COMPLETED'
               AND TRUNC(actual_dropoff) BETWEEN ? AND ?
             GROUP BY ROLLUP(TRUNC(actual_dropoff,'MM'))
             ORDER BY TRUNC(actual_dropoff,'MM') NULLS LAST
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
