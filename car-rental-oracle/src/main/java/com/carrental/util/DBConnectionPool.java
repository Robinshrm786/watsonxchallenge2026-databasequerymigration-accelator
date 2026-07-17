package com.carrental.util;

import java.io.InputStream;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Properties;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Thread-safe Oracle JDBC connection pool (manual pooling with bounded queue).
 * Uses Oracle Thin JDBC driver (ojdbc11.jar).
 * Pattern note: Oracle uses jdbc:oracle:thin:@ prefix
 *               PostgreSQL migration would use jdbc:postgresql://
 */
public class DBConnectionPool {

    private static final Logger LOG = Logger.getLogger(DBConnectionPool.class.getName());
    private static DBConnectionPool instance;

    private final String jdbcUrl;
    private final String username;
    private final String password;
    private final int    poolSize;

    private final java.util.concurrent.ArrayBlockingQueue<Connection> pool;

    private DBConnectionPool() {
        Properties props = loadProps();
        this.jdbcUrl  = props.getProperty("db.url",      "jdbc:oracle:thin:@localhost:1521:XEPDB1");
        this.username = props.getProperty("db.user",     "car_rental");
        this.password = props.getProperty("db.password", "car_rental_pass");
        this.poolSize = Integer.parseInt(props.getProperty("db.pool.size", "10"));

        pool = new java.util.concurrent.ArrayBlockingQueue<>(poolSize);

        try {
            // Oracle JDBC driver registration
            Class.forName("oracle.jdbc.OracleDriver");
            for (int i = 0; i < poolSize; i++) {
                pool.offer(createConnection());
            }
            LOG.info("DBConnectionPool initialized: " + poolSize + " connections to " + jdbcUrl);
        } catch (ClassNotFoundException e) {
            throw new RuntimeException("Oracle JDBC driver not found. Add ojdbc11.jar to classpath.", e);
        } catch (SQLException e) {
            throw new RuntimeException("Failed to initialize connection pool", e);
        }
    }

    private Connection createConnection() throws SQLException {
        Properties connProps = new Properties();
        connProps.setProperty("user",     username);
        connProps.setProperty("password", password);
        // Oracle-specific: enable statement caching (reduces parse overhead)
        connProps.setProperty("oracle.jdbc.implicitStatementCacheSize", "20");
        // Oracle-specific: set client info for auditing (SYS_CONTEXT)
        connProps.setProperty("v$session.program", "CarRentalApp");
        return DriverManager.getConnection(jdbcUrl, connProps);
    }

    private Properties loadProps() {
        Properties p = new Properties();
        try (InputStream is = getClass().getClassLoader().getResourceAsStream("db.properties")) {
            if (is != null) p.load(is);
        } catch (Exception e) {
            LOG.warning("db.properties not found, using defaults");
        }
        return p;
    }

    public static synchronized DBConnectionPool getInstance() {
        if (instance == null) instance = new DBConnectionPool();
        return instance;
    }

    /** Borrows a connection from the pool (blocks up to 30 seconds). */
    public Connection getConnection() throws SQLException {
        try {
            Connection conn = pool.poll(30, java.util.concurrent.TimeUnit.SECONDS);
            if (conn == null) throw new SQLException("Connection pool exhausted after 30s timeout");
            if (!conn.isValid(2)) {
                LOG.warning("Stale connection detected; creating new one");
                conn = createConnection();
            }
            return conn;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new SQLException("Interrupted while waiting for connection", e);
        }
    }

    /** Returns a connection back to the pool. */
    public void releaseConnection(Connection conn) {
        if (conn != null) {
            try {
                if (!conn.isClosed() && !conn.getAutoCommit()) {
                    conn.rollback();  // rollback any uncommitted work
                }
                pool.offer(conn);
            } catch (SQLException e) {
                LOG.log(Level.WARNING, "Error releasing connection", e);
            }
        }
    }

    /** Closes all pooled connections on shutdown. */
    public void shutdown() {
        for (Connection conn : pool) {
            try { conn.close(); } catch (SQLException ignored) {}
        }
        pool.clear();
        LOG.info("Connection pool shut down.");
    }
}
