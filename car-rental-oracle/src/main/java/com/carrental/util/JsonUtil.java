package com.carrental.util;

import com.carrental.model.Customer;
import com.carrental.model.Rental;
import com.carrental.model.Vehicle;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

/**
 * Minimal JSON serializer — no external library dependency.
 * Keeps the project portable (single jar, no Jackson/Gson required).
 */
public final class JsonUtil {

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ISO_LOCAL_DATE;
    private static final DateTimeFormatter DT_FMT   = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private JsonUtil() {}

    public static String ok(Object payload) {
        return "{\"success\":true,\"data\":" + toJson(payload) + "}";
    }

    public static String error(String message) {
        return "{\"success\":false,\"error\":" + quote(message) + "}";
    }

    @SuppressWarnings("unchecked")
    public static String toJson(Object obj) {
        if (obj == null)                   return "null";
        if (obj instanceof String)         return quote((String) obj);
        if (obj instanceof Number)         return obj.toString();
        if (obj instanceof Boolean)        return obj.toString();
        if (obj instanceof LocalDate)      return quote(DATE_FMT.format((LocalDate) obj));
        if (obj instanceof LocalDateTime)  return quote(DT_FMT.format((LocalDateTime) obj));
        if (obj instanceof java.sql.Timestamp) {
            return quote(DT_FMT.format(((java.sql.Timestamp) obj).toLocalDateTime()));
        }
        if (obj instanceof java.sql.Date)  return quote(DATE_FMT.format(((java.sql.Date) obj).toLocalDate()));
        if (obj instanceof Customer)       return customerJson((Customer) obj);
        if (obj instanceof Vehicle)        return vehicleJson((Vehicle) obj);
        if (obj instanceof Rental)         return rentalJson((Rental) obj);
        if (obj instanceof List)           return listJson((List<?>) obj);
        if (obj instanceof Object[])       return arrayRowJson((Object[]) obj);
        return quote(obj.toString());
    }

    private static String listJson(List<?> list) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < list.size(); i++) {
            if (i > 0) sb.append(",");
            sb.append(toJson(list.get(i)));
        }
        return sb.append("]").toString();
    }

    private static String arrayRowJson(Object[] row) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < row.length; i++) {
            if (i > 0) sb.append(",");
            sb.append(toJson(row[i]));
        }
        return sb.append("]").toString();
    }

    public static String customerJson(Customer c) {
        return "{" +
            field("customerId",    c.getCustomerId())    +
            field("firstName",     c.getFirstName())     +
            field("lastName",      c.getLastName())      +
            field("fullName",      c.getFullName())      +
            field("email",         c.getEmail())         +
            field("licenseNumber", c.getLicenseNumber()) +
            field("licenseExpiry", c.getLicenseExpiry()) +
            field("dateOfBirth",   c.getDateOfBirth())   +
            field("age",           c.getAge())           +
            field("loyaltyPoints", c.getLoyaltyPoints()) +
            field("tier",          c.getTier())          +
            field("isActive",      c.getIsActive())      +
            field("createdAt",     c.getCreatedAt())     +
            lastField("updatedAt", c.getUpdatedAt())     +
            "}";
    }

    public static String vehicleJson(Vehicle v) {
        return "{" +
            field("vehicleId",       v.getVehicleId())      +
            field("categoryId",      v.getCategoryId())     +
            field("categoryName",    v.getCategoryName())   +
            field("locationId",      v.getLocationId())     +
            field("locationName",    v.getLocationName())   +
            field("make",            v.getMake())           +
            field("model",           v.getModel())          +
            field("modelYear",       v.getModelYear())      +
            field("color",           v.getColor())          +
            field("licensePlate",    v.getLicensePlate())   +
            field("mileage",         v.getMileage())        +
            field("fuelType",        v.getFuelType())       +
            field("transmission",    v.getTransmission())   +
            field("seats",           v.getSeats())          +
            field("status",          v.getStatus())         +
            field("dailyRate",       v.getDailyRate())      +
            field("insuranceExpiry", v.getInsuranceExpiry())+
            lastField("displayName", v.getDisplayName())    +
            "}";
    }

    public static String rentalJson(Rental r) {
        return "{" +
            field("rentalId",           r.getRentalId())           +
            field("customerId",         r.getCustomerId())         +
            field("customerName",       r.getCustomerName())       +
            field("vehicleId",          r.getVehicleId())          +
            field("vehicleInfo",        r.getVehicleInfo())        +
            field("pickupLocationName", r.getPickupLocationName()) +
            field("dropoffLocationName",r.getDropoffLocationName())+
            field("actualPickup",       r.getActualPickup())       +
            field("actualDropoff",      r.getActualDropoff())      +
            field("odometerOut",        r.getOdometerOut())        +
            field("odometerIn",         r.getOdometerIn())         +
            field("fuelLevelOut",       r.getFuelLevelOut())       +
            field("baseCharge",         r.getBaseCharge())         +
            field("fuelCharge",         r.getFuelCharge())         +
            field("damageCharge",       r.getDamageCharge())       +
            field("lateFee",            r.getLateFee())            +
            field("totalCharge",        r.getTotalCharge())        +
            lastField("status",         r.getStatus())             +
            "}";
    }

    // ---- JSON field helpers ----
    private static String field(String key, Object value) {
        return quote(key) + ":" + toJson(value) + ",";
    }
    private static String lastField(String key, Object value) {
        return quote(key) + ":" + toJson(value);
    }
    private static String quote(String s) {
        if (s == null) return "null";
        return "\"" + s.replace("\\", "\\\\")
                       .replace("\"", "\\\"")
                       .replace("\n", "\\n")
                       .replace("\r", "\\r")
                       .replace("\t", "\\t") + "\"";
    }

    /** Parse a simple flat JSON object into key→value strings. */
    public static java.util.Map<String, String> parseFlat(String json) {
        java.util.Map<String, String> map = new java.util.LinkedHashMap<>();
        if (json == null || json.isBlank()) return map;
        // Strip outer braces
        String content = json.trim();
        if (content.startsWith("{")) content = content.substring(1);
        if (content.endsWith("}"))   content = content.substring(0, content.length()-1);
        // Split on commas not inside quotes (simplistic; sufficient for flat objects)
        for (String pair : content.split(",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)")) {
            String[] kv = pair.split(":", 2);
            if (kv.length == 2) {
                String k = kv[0].trim().replaceAll("^\"|\"$","");
                String v = kv[1].trim().replaceAll("^\"|\"$","");
                if (!"null".equals(v)) map.put(k, v);
            }
        }
        return map;
    }
}
