package com.carrental.dao;

import com.carrental.model.Customer;
import com.carrental.util.DBConnectionPool;

import java.sql.*;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.logging.Logger;

/**
 * DAO for CUSTOMERS table.
 *
 * Oracle patterns demonstrated:
 *  - Sequence.NEXTVAL in INSERT VALUES
 *  - Virtual columns (full_name, age) read from result set
 *  - RETURNING INTO via CallableStatement
 *  - Named bind variables with Oracle JDBC
 *  - Calling package procedure via CallableStatement with IN/OUT params
 */
public class CustomerDAO {

    private static final Logger LOG = Logger.getLogger(CustomerDAO.class.getName());

    // -----------------------------------------------------------------------
    // FIND ALL — with Oracle NVL, CASE for tier labelling
    // -----------------------------------------------------------------------
    public List<Customer> findAll(boolean activeOnly) throws SQLException {
        final String sql = """
            SELECT customer_id, first_name, last_name,
                   first_name || ' ' || last_name  AS full_name,
                   email, license_number, license_expiry, date_of_birth,
                   TRUNC(MONTHS_BETWEEN(SYSDATE, date_of_birth)/12) AS age,
                   loyalty_points, tier, notes, is_active,
                   created_at, updated_at
              FROM customers
             WHERE (:activeOnly = 0 OR is_active = 'Y')
             ORDER BY last_name, first_name
            """;
        Connection conn = DBConnectionPool.getInstance().getConnection();
        // Oracle named parameters via PreparedStatement index
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, activeOnly ? 1 : 0);
            return mapResultSet(ps.executeQuery());
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // FIND BY ID
    // -----------------------------------------------------------------------
    public Optional<Customer> findById(long customerId) throws SQLException {
        final String sql = """
            SELECT customer_id, first_name, last_name,
                   first_name || ' ' || last_name AS full_name,
                   email, license_number, license_expiry, date_of_birth,
                   TRUNC(MONTHS_BETWEEN(SYSDATE, date_of_birth)/12) AS age,
                   loyalty_points, tier, notes, is_active,
                   created_at, updated_at
              FROM customers
             WHERE customer_id = ?
            """;
        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, customerId);
            List<Customer> r = mapResultSet(ps.executeQuery());
            return r.isEmpty() ? Optional.empty() : Optional.of(r.get(0));
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // SEARCH — function-based index: UPPER(email)
    // -----------------------------------------------------------------------
    public List<Customer> search(String keyword) throws SQLException {
        final String sql = """
            SELECT customer_id, first_name, last_name,
                   first_name || ' ' || last_name AS full_name,
                   email, license_number, license_expiry, date_of_birth,
                   TRUNC(MONTHS_BETWEEN(SYSDATE, date_of_birth)/12) AS age,
                   loyalty_points, tier, notes, is_active,
                   created_at, updated_at
              FROM customers
             WHERE is_active = 'Y'
               AND (UPPER(first_name || ' ' || last_name) LIKE UPPER(?)
                 OR UPPER(email)          LIKE UPPER(?)
                 OR UPPER(license_number) LIKE UPPER(?))
             ORDER BY last_name, first_name
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
    // INSERT — Oracle sequence.NEXTVAL, trigger handles updated_at
    // -----------------------------------------------------------------------
    public long insert(Customer c) throws SQLException {
        // Note: trigger trg_customers_bi sets tier and updated_at automatically
        final String sql = """
            INSERT INTO customers (
                customer_id, first_name, last_name, email,
                license_number, license_expiry, date_of_birth,
                loyalty_points, notes, is_active
            ) VALUES (
                seq_customer_id.NEXTVAL, ?, ?, ?,
                ?, ?, ?,
                ?, ?, 'Y'
            )
            """;

        Connection conn = DBConnectionPool.getInstance().getConnection();
        // Use PreparedStatement with getGeneratedKeys (requires returning clause)
        // Oracle JDBC: use KEY_COLUMN_NAMES for generated key retrieval
        try (PreparedStatement ps = conn.prepareStatement(sql,
                new String[]{"customer_id"})) {
            ps.setString(1, c.getFirstName());
            ps.setString(2, c.getLastName());
            ps.setString(3, c.getEmail());
            ps.setString(4, c.getLicenseNumber());
            ps.setDate(5,   Date.valueOf(c.getLicenseExpiry()));
            ps.setDate(6,   Date.valueOf(c.getDateOfBirth()));
            ps.setInt(7,    c.getLoyaltyPoints() != null ? c.getLoyaltyPoints() : 0);
            if (c.getNotes() != null) {
                // Oracle CLOB handling
                Clob clob = conn.createClob();
                clob.setString(1, c.getNotes());
                ps.setClob(8, clob);
            } else {
                ps.setNull(8, Types.CLOB);
            }
            ps.executeUpdate();
            try (ResultSet generatedKeys = ps.getGeneratedKeys()) {
                if (generatedKeys.next()) {
                    long newId = generatedKeys.getLong(1);
                    conn.commit();
                    LOG.info("Inserted customer id=" + newId);
                    return newId;
                }
            }
            conn.rollback();
            throw new SQLException("Insert customer failed, no ID obtained.");
        } catch (SQLException e) {
            conn.rollback();
            throw e;
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // UPDATE — uses SYSTIMESTAMP (trigger also fires bu)
    // -----------------------------------------------------------------------
    public void update(Customer c) throws SQLException {
        final String sql = """
            UPDATE customers
               SET first_name     = ?,
                   last_name      = ?,
                   email          = ?,
                   license_number = ?,
                   license_expiry = ?,
                   date_of_birth  = ?,
                   notes          = ?,
                   loyalty_points = ?,
                   updated_at     = SYSTIMESTAMP
             WHERE customer_id = ?
            """;
        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, c.getFirstName());
            ps.setString(2, c.getLastName());
            ps.setString(3, c.getEmail());
            ps.setString(4, c.getLicenseNumber());
            ps.setDate(5,   Date.valueOf(c.getLicenseExpiry()));
            ps.setDate(6,   Date.valueOf(c.getDateOfBirth()));
            if (c.getNotes() != null) {
                Clob clob = conn.createClob();
                clob.setString(1, c.getNotes());
                ps.setClob(7, clob);
            } else {
                ps.setNull(7, Types.CLOB);
            }
            ps.setInt(8,  c.getLoyaltyPoints() != null ? c.getLoyaltyPoints() : 0);
            ps.setLong(9, c.getCustomerId());
            int updated = ps.executeUpdate();
            if (updated == 0) throw new SQLException("No customer found with id=" + c.getCustomerId());
            conn.commit();
        } catch (SQLException e) {
            conn.rollback();
            throw e;
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // Soft-delete (set is_active = 'N')
    // -----------------------------------------------------------------------
    public void softDelete(long customerId) throws SQLException {
        final String sql = "UPDATE customers SET is_active='N', updated_at=SYSTIMESTAMP WHERE customer_id=?";
        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, customerId);
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
    // Rental history with window functions — called from report
    // -----------------------------------------------------------------------
    public List<Object[]> getRentalHistory(long customerId) throws SQLException {
        final String sql = """
            SELECT r.rental_id,
                   v.make || ' ' || v.model                         AS vehicle,
                   v.license_plate,
                   r.actual_pickup, r.actual_dropoff,
                   r.total_charge,
                   SUM(r.total_charge) OVER (
                       PARTITION BY r.customer_id
                       ORDER BY r.actual_pickup
                       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                   ) AS running_total,
                   RANK() OVER (
                       PARTITION BY r.customer_id ORDER BY r.total_charge DESC
                   ) AS charge_rank
              FROM rentals  r
              JOIN vehicles v ON r.vehicle_id = v.vehicle_id
             WHERE r.customer_id = ?
               AND r.status = 'COMPLETED'
             ORDER BY r.actual_pickup DESC
            """;
        List<Object[]> rows = new ArrayList<>();
        Connection conn = DBConnectionPool.getInstance().getConnection();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, customerId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    rows.add(new Object[]{
                        rs.getLong("rental_id"),
                        rs.getString("vehicle"),
                        rs.getString("license_plate"),
                        rs.getTimestamp("actual_pickup"),
                        rs.getTimestamp("actual_dropoff"),
                        rs.getBigDecimal("total_charge"),
                        rs.getBigDecimal("running_total"),
                        rs.getInt("charge_rank")
                    });
                }
            }
            return rows;
        } finally {
            DBConnectionPool.getInstance().releaseConnection(conn);
        }
    }

    // -----------------------------------------------------------------------
    // HELPER: map ResultSet → Customer
    // -----------------------------------------------------------------------
    private List<Customer> mapResultSet(ResultSet rs) throws SQLException {
        List<Customer> list = new ArrayList<>();
        while (rs.next()) {
            Customer c = new Customer();
            c.setCustomerId(rs.getLong("customer_id"));
            c.setFirstName(rs.getString("first_name"));
            c.setLastName(rs.getString("last_name"));
            c.setFullName(rs.getString("full_name"));
            c.setEmail(rs.getString("email"));
            c.setLicenseNumber(rs.getString("license_number"));
            Date le = rs.getDate("license_expiry");
            c.setLicenseExpiry(le != null ? le.toLocalDate() : null);
            Date dob = rs.getDate("date_of_birth");
            c.setDateOfBirth(dob != null ? dob.toLocalDate() : null);
            c.setAge(rs.getInt("age"));
            c.setLoyaltyPoints(rs.getInt("loyalty_points"));
            c.setTier(rs.getString("tier"));
            c.setIsActive(rs.getString("is_active"));
            Timestamp ca = rs.getTimestamp("created_at");
            c.setCreatedAt(ca != null ? ca.toLocalDateTime() : null);
            Timestamp ua = rs.getTimestamp("updated_at");
            c.setUpdatedAt(ua != null ? ua.toLocalDateTime() : null);
            list.add(c);
        }
        return list;
    }
}
