package com.carrental.servlet;

import com.carrental.dao.VehicleDAO;
import com.carrental.model.Vehicle;
import com.carrental.util.JsonUtil;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.io.PrintWriter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * REST servlet for Vehicle operations.
 * Routes:
 *  GET  /api/vehicles                              — all available vehicles
 *  GET  /api/vehicles?id=N                         — by ID
 *  GET  /api/vehicles?search=keyword               — search
 *  GET  /api/vehicles?action=utilization&id=N&from=&to= — utilization rate
 *  GET  /api/vehicles?action=revenue&from=&to=     — monthly revenue (pipelined fn)
 *  POST /api/vehicles                              — create vehicle
 */
@WebServlet(name = "VehicleServlet", urlPatterns = {"/api/vehicles", "/api/vehicles/*"})
public class VehicleServlet extends HttpServlet {

    private static final Logger LOG = Logger.getLogger(VehicleServlet.class.getName());
    private final VehicleDAO vehicleDAO = new VehicleDAO();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setContentType("application/json;charset=UTF-8");
        PrintWriter out = resp.getWriter();
        try {
            String idParam      = req.getParameter("id");
            String search       = req.getParameter("search");
            String action       = req.getParameter("action");
            String locationParam= req.getParameter("locationId");
            String categoryParam= req.getParameter("categoryId");

            if ("utilization".equals(action) && idParam != null) {
                long vid   = Long.parseLong(idParam);
                LocalDate from = parseDate(req.getParameter("from"), LocalDate.now().minusMonths(1));
                LocalDate to   = parseDate(req.getParameter("to"),   LocalDate.now());
                BigDecimal rate = vehicleDAO.getUtilizationRate(vid, from, to);
                out.print("{\"success\":true,\"vehicleId\":" + vid +
                          ",\"utilizationPct\":" + rate + "}");

            } else if ("revenue".equals(action)) {
                LocalDate from = parseDate(req.getParameter("from"), LocalDate.now().minusMonths(6));
                LocalDate to   = parseDate(req.getParameter("to"),   LocalDate.now());
                List<Object[]> rows = vehicleDAO.getMonthlyRevenue(from, to);
                StringBuilder sb = new StringBuilder("{\"success\":true,\"columns\":");
                sb.append("[\"period\",\"rentals\",\"revenue\"],\"rows\":[");
                for (int i = 0; i < rows.size(); i++) {
                    if (i > 0) sb.append(",");
                    sb.append(JsonUtil.toJson(rows.get(i)));
                }
                out.print(sb.append("]}").toString());

            } else if (idParam != null) {
                Optional<Vehicle> v = vehicleDAO.findById(Long.parseLong(idParam));
                if (v.isPresent()) {
                    out.print(JsonUtil.ok(v.get()));
                } else {
                    resp.setStatus(404);
                    out.print(JsonUtil.error("Vehicle not found: " + idParam));
                }

            } else if (search != null && !search.isBlank()) {
                List<Vehicle> results = vehicleDAO.search(search);
                out.print(JsonUtil.ok(results));

            } else {
                Integer locId = locationParam != null ? Integer.parseInt(locationParam) : null;
                List<Vehicle> available = vehicleDAO.findAvailable(locId, categoryParam);
                out.print(JsonUtil.ok(available));
            }

        } catch (Exception e) {
            LOG.log(Level.SEVERE, "VehicleServlet GET error", e);
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
            Vehicle v = new Vehicle();
            v.setCategoryId(Integer.parseInt(body.get("categoryId")));
            String locId = body.get("locationId");
            v.setLocationId(locId != null ? Integer.parseInt(locId) : null);
            v.setMake(body.get("make"));
            v.setModel(body.get("model"));
            v.setModelYear(Integer.parseInt(body.get("modelYear")));
            v.setColor(body.get("color"));
            v.setVin(body.get("vin"));
            v.setLicensePlate(body.get("licensePlate"));
            v.setFuelType(body.getOrDefault("fuelType", "GASOLINE"));
            v.setTransmission(body.getOrDefault("transmission", "AUTOMATIC"));
            String seats = body.get("seats");
            v.setSeats(seats != null ? Integer.parseInt(seats) : 5);
            String override = body.get("dailyOverride");
            v.setDailyOverride(override != null ? new BigDecimal(override) : null);
            v.setMileage(0L);

            long newId = vehicleDAO.insert(v);
            out.print("{\"success\":true,\"vehicleId\":" + newId + "}");

        } catch (Exception e) {
            LOG.log(Level.SEVERE, "VehicleServlet POST error", e);
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

    private LocalDate parseDate(String s, LocalDate def) {
        try { return (s != null && !s.isBlank()) ? LocalDate.parse(s) : def; }
        catch (Exception e) { return def; }
    }
}
