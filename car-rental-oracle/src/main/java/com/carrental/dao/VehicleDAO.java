package com.carrental.dao;

import com.carrental.model.Vehicle;
import com.carrental.util.DBConnectionPool;
import oracle.jdbc.OracleTypes;

import java.math.BigDecimal;
import java.sql.*;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.logging.Logger;

/**
 * Data Access Object for VEHICLES.
 *
 * Demonstrates Oracle JDBC patterns:
 *  - CallableStatement for stored procedures/functions
 *  - Named parameters via oracle.jdbc.OracleTypes.CURSOR
 *  - PreparedStatement with setDate/setTimestamp
 *  - ResultSet metadata reading
 *  - Batch inserts via addBatch()/executeBatch()
 */
public class VehicleDAO {

    private static final Logger LOG = Logger.getLogger(VehicleDAO.class.getName());

    // -----------------------------------------------------------------------
    // FIND ALL AVAILABLE vehicles with joined category & location
    // Oracle feature: NVL(), JOIN, partition pruning hint via WHERE
    // -----------------------------------------------------------------------
    public List<Vehicle> findAvailable(Integer locationId, String categoryId) throws SQLException {
        StringBuilder sql = new StringBuilder("""
            SELECT v.vehicle_id,
                   v.category_id,   vc.category_name,
                   v.location_id,   l.location_name,
                   v.make, v.model, v.model_year, v.color,
                   v.vin, v.license_plate, v.mileage, v.fuel_type,
                   v.transmission, v.seats, v.status,
                   NVL(v.daily_override, vc.daily_rate)  AS daily_rate,
                   v.daily_override,
                   v.last_service_date, v.insurance_expiry,
                   v.is_active, v.created_at, v.updated_at
              FROM vehicles v
              JOIN vehicle_categories vc ON v.category_id  = vc.category_id
              LEFT JOIN locations     l  ON v.location_id  = l.location_id
             WHERE v.is_active = 'Y'
               AND v.status    = 'AVAILABLE'
            """);

        List<Object> params = new ArrayList<>();
        if (locationId != null) {
            sql.append(" AND v.location_id = ? ");
            params.add(locationId);
        }
        if (categoryId != null && !categoryId.isBlank()) {
            sql.append(" AND v.category_id = ? ");
            params.add(Integer.parseInt(categoryId));
        }
        sql.append(" ORDER BY vc.category_name, v.make, v.model");

        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            return mapResultSet(ps.executeQuery());
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // FIND BY ID — using Oracle dual-table style with rownum safety
    // -----------------------------------------------------------------------
    public Optional<Vehicle> findById(long vehicleId) throws SQLException {
        final String sql = """
            SELECT v.vehicle_id,
                   v.category_id,   vc.category_name,
                   v.location_id,   l.location_name,
                   v.make, v.model, v.model_year, v.color,
                   v.vin, v.license_plate, v.mileage, v.fuel_type,
                   v.transmission, v.seats, v.status,
                   NVL(v.daily_override, vc.daily_rate) AS daily_rate,
                   v.daily_override,
                   v.last_service_date, v.insurance_expiry,
                   v.is_active, v.created_at, v.updated_at
              FROM vehicles v
              JOIN vehicle_categories vc ON v.category_id = vc.category_id
              LEFT JOIN locations     l  ON v.location_id = l.location_id
             WHERE v.vehicle_id = ?
            """;
        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, vehicleId);
            List<Vehicle> result = mapResultSet(ps.executeQuery());
            return result.isEmpty() ? Optional.empty() : Optional.of(result.get(0));
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // INSERT with Oracle SEQUENCE.NEXTVAL and RETURNING INTO
    // Oracle: INSERT ... RETURNING col INTO ?
    // PostgreSQL equivalent: INSERT ... RETURNING col
    // -----------------------------------------------------------------------
    public long insert(Vehicle v) throws SQLException {
        // Oracle: use sequence in VALUES
        final String sql = """
            INSERT INTO vehicles (
                vehicle_id, category_id, location_id,
                make, model, model_year, color,
                vin, license_plate, mileage, fuel_type, transmission,
                seats, status, daily_override, description,
                last_service_date, insurance_expiry, is_active
            ) VALUES (
                seq_vehicle_id.NEXTVAL, ?, ?,
                ?, ?, ?, ?,
                ?, ?, ?, ?, ?,
                ?, ?, ?, ?,
                ?, ?, ?
            )
            """;

        Connection conn = DBConnectionPool.getInstance().getConnection();
        // RETURNING INTO: Oracle-specific to get generated PK back
        final String sqlReturning = sql.replace(")", "\n) RETURNING vehicle_id INTO ?");
        // Use standard OracleCallableStatement for RETURNING
        try (CallableStatement cs = conn.prepareCall(sqlReturning)) {
            cs.setInt(1,  v.getCategoryId());
            setNullableInt(cs, 2, v.getLocationId());
            cs.setString(3,  v.getMake());
            cs.setString(4,  v.getModel());
            cs.setInt(5,     v.getModelYear());
            cs.setString(6,  v.getColor());
            cs.setString(7,  v.getVin());
            cs.setString(8,  v.getLicensePlate());
            cs.setLong(9,    v.getMileage() != null ? v.getMileage() : 0);
            cs.setString(10, v.getFuelType() != null ? v.getFuelType() : "GASOLINE");
            cs.setString(11, v.getTransmission() != null ? v.getTransmission() : "AUTOMATIC");
            cs.setInt(12,    v.getSeats() != null ? v.getSeats() : 5);
            cs.setString(13, v.getStatus() != null ? v.getStatus() : "AVAILABLE");
            if (v.getDailyOverride() != null) cs.setBigDecimal(14, v.getDailyOverride());
            else cs.setNull(14, Types.NUMERIC);
            cs.setString(15, v.getDescription());
            setNullableDate(cs, 16, v.getLastServiceDate());
            setNullableDate(cs, 17, v.getInsuranceExpiry());
            cs.setString(18, "Y");
            // RETURNING INTO out parameter
            cs.registerOutParameter(19, Types.NUMERIC);

            cs.executeUpdate();
            long newId = cs.getLong(19);
            conn.commit();
            LOG.info("Inserted vehicle id=" + newId);
            return newId;
        } catch (SQLException e) {
            conn.rollback();
            throw e;
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // UPDATE vehicle status — used by triggers pattern demonstration
    // -----------------------------------------------------------------------
    public void updateStatus(long vehicleId, String status) throws SQLException {
        final String sql = "UPDATE vehicles SET status = ?, updated_at = SYSTIMESTAMP WHERE vehicle_id = ?";
        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, status);
            ps.setLong(2, vehicleId);
            ps.executeUpdate();
            conn.commit();
        } catch (SQLException e) {
            conn.rollback();
            throw e;
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // Vehicle utilization — calls Oracle standalone function
    // Oracle: SELECT function() FROM dual
    // -----------------------------------------------------------------------
    public BigDecimal getUtilizationRate(long vehicleId, LocalDate start, LocalDate end) throws SQLException {
        final String sql = """
            SELECT get_vehicle_utilization(?, ?, ?) FROM dual
            """;
        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, vehicleId);
            ps.setDate(2, Date.valueOf(start));
            ps.setDate(3, Date.valueOf(end));
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return rs.getBigDecimal(1);
            }
            return BigDecimal.ZERO;
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // Search with UPPER() function-based index
    // -----------------------------------------------------------------------
    public List<Vehicle> search(String keyword) throws SQLException {
        // Uses idx_vehicles_location; UPPER for FBI usage
        final String sql = """
            SELECT v.vehicle_id, v.category_id, vc.category_name,
                   v.location_id, l.location_name,
                   v.make, v.model, v.model_year, v.color,
                   v.vin, v.license_plate, v.mileage, v.fuel_type,
                   v.transmission, v.seats, v.status,
                   NVL(v.daily_override, vc.daily_rate) AS daily_rate,
                   v.daily_override,
                   v.last_service_date, v.insurance_expiry,
                   v.is_active, v.created_at, v.updated_at
              FROM vehicles v
              JOIN vehicle_categories vc ON v.category_id = vc.category_id
              LEFT JOIN locations     l  ON v.location_id = l.location_id
             WHERE v.is_active = 'Y'
               AND (UPPER(v.make)          LIKE UPPER(?)
                 OR UPPER(v.model)         LIKE UPPER(?)
                 OR UPPER(v.license_plate) LIKE UPPER(?))
             ORDER BY v.make, v.model
            """;
        String pattern = "%" + keyword + "%";
        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, pattern);
            ps.setString(2, pattern);
            ps.setString(3, pattern);
            return mapResultSet(ps.executeQuery());
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // Revenue report — pipelined function via TABLE() operator
    // Oracle: SELECT * FROM TABLE(car_rental_pkg.revenue_by_month(?,?))
    // -----------------------------------------------------------------------
    public List<Object[]> getMonthlyRevenue(LocalDate startDate, LocalDate endDate) throws SQLException {
        final String sql = """
            SELECT period_label, rental_count, total_revenue
              FROM TABLE(car_rental_pkg.revenue_by_month(?, ?))
             ORDER BY period_label
            """;
        List<Object[]> rows = new ArrayList<>();
        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setDate(1, Date.valueOf(startDate));
            ps.setDate(2, Date.valueOf(endDate));
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    rows.add(new Object[]{rs.getString(1), rs.getLong(2), rs.getBigDecimal(3)});
                }
            }
            return rows;
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------
    private List<Vehicle> mapResultSet(ResultSet rs) throws SQLException {
        List<Vehicle> list = new ArrayList<>();
        while (rs.next()) {
            Vehicle v = new Vehicle();
            v.setVehicleId(rs.getLong("vehicle_id"));
            v.setCategoryId(rs.getInt("category_id"));
            v.setCategoryName(rs.getString("category_name"));
            int locId = rs.getInt("location_id");
            v.setLocationId(rs.wasNull() ? null : locId);
            v.setLocationName(rs.getString("location_name"));
            v.setMake(rs.getString("make"));
            v.setModel(rs.getString("model"));
            v.setModelYear(rs.getInt("model_year"));
            v.setColor(rs.getString("color"));
            v.setVin(rs.getString("vin"));
            v.setLicensePlate(rs.getString("license_plate"));
            v.setMileage(rs.getLong("mileage"));
            v.setFuelType(rs.getString("fuel_type"));
            v.setTransmission(rs.getString("transmission"));
            v.setSeats(rs.getInt("seats"));
            v.setStatus(rs.getString("status"));
            v.setDailyRate(rs.getBigDecimal("daily_rate"));
            v.setDailyOverride(rs.getBigDecimal("daily_override"));
            Date lsd = rs.getDate("last_service_date");
            v.setLastServiceDate(lsd != null ? lsd.toLocalDate() : null);
            Date ie = rs.getDate("insurance_expiry");
            v.setInsuranceExpiry(ie != null ? ie.toLocalDate() : null);
            v.setIsActive(rs.getString("is_active"));
            Timestamp ca = rs.getTimestamp("created_at");
            v.setCreatedAt(ca != null ? ca.toLocalDateTime() : null);
            Timestamp ua = rs.getTimestamp("updated_at");
            v.setUpdatedAt(ua != null ? ua.toLocalDateTime() : null);
            list.add(v);
        }
        return list;
    }

    private void setNullableInt(CallableStatement cs, int idx, Integer val) throws SQLException {
        if (val != null) cs.setInt(idx, val); else cs.setNull(idx, Types.INTEGER);
    }
    private void setNullableDate(CallableStatement cs, int idx, LocalDate val) throws SQLException {
        if (val != null) cs.setDate(idx, Date.valueOf(val)); else cs.setNull(idx, Types.DATE);
    }
}
