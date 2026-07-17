package com.carrental.servlet;

import com.carrental.dao.VehicleDAO;
import com.carrental.dao.CustomerDAO;
import com.carrental.dao.RentalDAO;
import com.carrental.model.Rental;
import com.carrental.util.JsonUtil;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.io.PrintWriter;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * REST-style servlet handling all Rental operations.
 * Routes:
 *  GET  /api/rentals            — list active rentals
 *  GET  /api/rentals?id=N       — get single rental
 *  GET  /api/rentals?action=overdue  — overdue rentals
 *  GET  /api/rentals?action=report&from=YYYY-MM-DD&to=YYYY-MM-DD  — revenue report
 *  GET  /api/rentals?action=dashboard — dashboard stats
 *  POST /api/rentals            — begin rental  {action:"begin", reservationId, employeeId, odometerOut}
 *  PUT  /api/rentals            — complete rental {rentalId, employeeId, odometerIn, fuelLevelIn, damageNotes}
 */
@WebServlet(name = "RentalServlet", urlPatterns = {"/api/rentals", "/api/rentals/*"})
public class RentalServlet extends HttpServlet {

    private static final Logger LOG = Logger.getLogger(RentalServlet.class.getName());
    private final RentalDAO rentalDAO = new RentalDAO();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setContentType("application/json;charset=UTF-8");
        PrintWriter out = resp.getWriter();
        try {
            String idParam  = req.getParameter("id");
            String action   = req.getParameter("action");

            if (idParam != null) {
                // Single rental by ID
                Optional<Rental> rental = rentalDAO.findById(Long.parseLong(idParam));
                if (rental.isPresent()) {
                    out.print(JsonUtil.ok(rental.get()));
                } else {
                    resp.setStatus(404);
                    out.print(JsonUtil.error("Rental not found: " + idParam));
                }

            } else if ("overdue".equals(action)) {
                List<Rental> overdue = rentalDAO.findOverdue();
                out.print(JsonUtil.ok(overdue));

            } else if ("report".equals(action)) {
                LocalDate from = parseDate(req.getParameter("from"), LocalDate.now().withDayOfMonth(1));
                LocalDate to   = parseDate(req.getParameter("to"),   LocalDate.now());
                List<Object[]> rows = rentalDAO.getRevenueReport(from, to);
                out.print(buildReportJson(rows));

            } else if ("dashboard".equals(action)) {
                List<Object[]> stats = rentalDAO.getDashboardStats();
                out.print(buildDashboardJson(stats));

            } else {
                // Active rentals list
                List<Rental> active = rentalDAO.findActive();
                out.print(JsonUtil.ok(active));
            }

        } catch (Exception e) {
            LOG.log(Level.SEVERE, "RentalServlet GET error", e);
            resp.setStatus(500);
            out.print(JsonUtil.error(e.getMessage()));
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setContentType("application/json;charset=UTF-8");
        PrintWriter out = resp.getWriter();
        try {
            Map<String, String> body = readBody(req);
            String action = body.getOrDefault("action", "begin");

            if ("begin".equals(action)) {
                long reservationId = Long.parseLong(body.get("reservationId"));
                long employeeId    = Long.parseLong(body.get("employeeId"));
                long odometerOut   = Long.parseLong(body.get("odometerOut"));
                long rentalId = rentalDAO.beginRental(reservationId, employeeId, odometerOut);
                out.print("{\"success\":true,\"rentalId\":" + rentalId + "}");
            } else {
                resp.setStatus(400);
                out.print(JsonUtil.error("Unknown action: " + action));
            }

        } catch (Exception e) {
            LOG.log(Level.SEVERE, "RentalServlet POST error", e);
            resp.setStatus(500);
            out.print(JsonUtil.error(e.getMessage()));
        }
    }

    @Override
    protected void doPut(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setContentType("application/json;charset=UTF-8");
        PrintWriter out = resp.getWriter();
        try {
            Map<String, String> body = readBody(req);
            long   rentalId     = Long.parseLong(body.get("rentalId"));
            long   employeeId   = Long.parseLong(body.get("employeeId"));
            long   odometerIn   = Long.parseLong(body.get("odometerIn"));
            int    fuelLevelIn  = Integer.parseInt(body.getOrDefault("fuelLevelIn","100"));
            String damageNotes  = body.get("damageNotes");

            rentalDAO.completeRental(rentalId, employeeId, odometerIn, fuelLevelIn, damageNotes);
            out.print("{\"success\":true,\"message\":\"Rental " + rentalId + " completed\"}");

        } catch (Exception e) {
            LOG.log(Level.SEVERE, "RentalServlet PUT error", e);
            resp.setStatus(500);
            out.print(JsonUtil.error(e.getMessage()));
        }
    }

    // ---- Helpers ----

    private String buildReportJson(List<Object[]> rows) {
        StringBuilder sb = new StringBuilder("{\"success\":true,\"columns\":");
        sb.append("[\"period\",\"rentals\",\"total_revenue\",\"avg_revenue\",")
          .append("\"base_rev\",\"fuel_rev\",\"damage_rev\",\"late_fees\"],\"rows\":[");
        for (int i = 0; i < rows.size(); i++) {
            if (i > 0) sb.append(",");
            sb.append(JsonUtil.toJson(rows.get(i)));
        }
        return sb.append("]}").toString();
    }

    private String buildDashboardJson(List<Object[]> rows) {
        StringBuilder sb = new StringBuilder("{\"success\":true,\"stats\":[");
        for (int i = 0; i < rows.size(); i++) {
            if (i > 0) sb.append(",");
            Object[] r = rows.get(i);
            sb.append("{\"status\":").append(JsonUtil.toJson(r[0]))
              .append(",\"count\":").append(JsonUtil.toJson(r[1]))
              .append(",\"totalRevenue\":").append(JsonUtil.toJson(r[2]))
              .append(",\"avgCharge\":").append(JsonUtil.toJson(r[3]))
              .append(",\"maxCharge\":").append(JsonUtil.toJson(r[4]))
              .append("}");
        }
        return sb.append("]}").toString();
    }

    private Map<String, String> readBody(HttpServletRequest req) throws IOException {
        StringBuilder sb = new StringBuilder();
        try (java.io.BufferedReader reader = req.getReader()) {
            String line;
            while ((line = reader.readLine()) != null) sb.append(line);
        }
        return JsonUtil.parseFlat(sb.toString());
    }

    private LocalDate parseDate(String s, LocalDate def) {
        try { return (s != null && !s.isBlank()) ? LocalDate.parse(s) : def; }
        catch (Exception e) { return def; }
    }
}
