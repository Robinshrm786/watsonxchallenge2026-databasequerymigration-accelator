package com.carrental.servlet;

import com.carrental.dao.CustomerDAO;
import com.carrental.model.Customer;
import com.carrental.util.JsonUtil;

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
 * REST servlet for Customer CRUD.
 * Routes:
 *  GET  /api/customers                   — all active customers
 *  GET  /api/customers?id=N              — by ID
 *  GET  /api/customers?search=keyword    — search
 *  GET  /api/customers?id=N&action=history — rental history
 *  POST /api/customers                   — create
 *  PUT  /api/customers                   — update
 *  DELETE /api/customers?id=N            — soft delete
 */
@WebServlet(name = "CustomerServlet", urlPatterns = {"/api/customers", "/api/customers/*"})
public class CustomerServlet extends HttpServlet {

    private static final Logger LOG = Logger.getLogger(CustomerServlet.class.getName());
    private final CustomerDAO customerDAO = new CustomerDAO();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setContentType("application/json;charset=UTF-8");
        PrintWriter out = resp.getWriter();
        try {
            String idParam  = req.getParameter("id");
            String search   = req.getParameter("search");
            String action   = req.getParameter("action");

            if (idParam != null && "history".equals(action)) {
                long custId = Long.parseLong(idParam);
                List<Object[]> history = customerDAO.getRentalHistory(custId);
                StringBuilder sb = new StringBuilder("{\"success\":true,");
                sb.append("\"columns\":[\"rentalId\",\"vehicle\",\"licensePlate\",")
                  .append("\"pickup\",\"dropoff\",\"charge\",\"runningTotal\",\"rank\"],\"rows\":[");
                for (int i = 0; i < history.size(); i++) {
                    if (i > 0) sb.append(",");
                    sb.append(JsonUtil.toJson(history.get(i)));
                }
                out.print(sb.append("]}").toString());

            } else if (idParam != null) {
                Optional<Customer> c = customerDAO.findById(Long.parseLong(idParam));
                if (c.isPresent()) {
                    out.print(JsonUtil.ok(c.get()));
                } else {
                    resp.setStatus(404);
                    out.print(JsonUtil.error("Customer not found: " + idParam));
                }

            } else if (search != null && !search.isBlank()) {
                List<Customer> results = customerDAO.search(search);
                out.print(JsonUtil.ok(results));

            } else {
                List<Customer> all = customerDAO.findAll(true);
                out.print(JsonUtil.ok(all));
            }

        } catch (Exception e) {
            LOG.log(Level.SEVERE, "CustomerServlet GET error", e);
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
            Customer c = new Customer();
            c.setFirstName(body.get("firstName"));
            c.setLastName(body.get("lastName"));
            c.setEmail(body.get("email"));
            c.setLicenseNumber(body.get("licenseNumber"));
            c.setLicenseExpiry(LocalDate.parse(body.get("licenseExpiry")));
            c.setDateOfBirth(LocalDate.parse(body.get("dateOfBirth")));
            c.setNotes(body.get("notes"));
            c.setLoyaltyPoints(0);

            long newId = customerDAO.insert(c);
            out.print("{\"success\":true,\"customerId\":" + newId + "}");

        } catch (Exception e) {
            LOG.log(Level.SEVERE, "CustomerServlet POST error", e);
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
            Customer c = new Customer();
            c.setCustomerId(Long.parseLong(body.get("customerId")));
            c.setFirstName(body.get("firstName"));
            c.setLastName(body.get("lastName"));
            c.setEmail(body.get("email"));
            c.setLicenseNumber(body.get("licenseNumber"));
            c.setLicenseExpiry(LocalDate.parse(body.get("licenseExpiry")));
            c.setDateOfBirth(LocalDate.parse(body.get("dateOfBirth")));
            c.setNotes(body.get("notes"));
            String lp = body.get("loyaltyPoints");
            c.setLoyaltyPoints(lp != null ? Integer.parseInt(lp) : 0);

            customerDAO.update(c);
            out.print("{\"success\":true,\"message\":\"Customer updated\"}");

        } catch (Exception e) {
            LOG.log(Level.SEVERE, "CustomerServlet PUT error", e);
            resp.setStatus(500);
            out.print(JsonUtil.error(e.getMessage()));
        }
    }

    @Override
    protected void doDelete(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setContentType("application/json;charset=UTF-8");
        PrintWriter out = resp.getWriter();
        try {
            String idParam = req.getParameter("id");
            if (idParam == null) {
                resp.setStatus(400);
                out.print(JsonUtil.error("id parameter required"));
                return;
            }
            customerDAO.softDelete(Long.parseLong(idParam));
            out.print("{\"success\":true,\"message\":\"Customer deactivated\"}");
        } catch (Exception e) {
            LOG.log(Level.SEVERE, "CustomerServlet DELETE error", e);
            resp.setStatus(500);
            out.print(JsonUtil.error(e.getMessage()));
        }
    }

    private Map<String, String> readBody(HttpServletRequest req) throws IOException {
        StringBuilder sb = new StringBuilder();
        try (java.io.BufferedReader reader = req.getReader()) {
            String line;
            while ((line = reader.readLine()) != null) sb.append(line);
        }
        return JsonUtil.parseFlat(sb.toString());
    }
}
