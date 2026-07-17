package com.carrental.model;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/** Maps to VEHICLES table + joined category info. */
public class Vehicle {

    private Long       vehicleId;
    private Integer    categoryId;
    private String     categoryName;
    private Integer    locationId;
    private String     locationName;
    private String     make;
    private String     model;
    private Integer    modelYear;
    private String     color;
    private String     vin;
    private String     licensePlate;
    private Long       mileage;
    private String     fuelType;
    private String     transmission;
    private Integer    seats;
    private String     status;
    private BigDecimal dailyRate;       // from category or override
    private BigDecimal dailyOverride;
    private String     description;
    private LocalDate  lastServiceDate;
    private LocalDate  insuranceExpiry;
    private String     isActive;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public Vehicle() {}

    // ---- Getters / Setters ----
    public Long       getVehicleId()      { return vehicleId; }
    public void       setVehicleId(Long v)    { this.vehicleId = v; }
    public Integer    getCategoryId()     { return categoryId; }
    public void       setCategoryId(Integer v){ this.categoryId = v; }
    public String     getCategoryName()   { return categoryName; }
    public void       setCategoryName(String v){ this.categoryName = v; }
    public Integer    getLocationId()     { return locationId; }
    public void       setLocationId(Integer v){ this.locationId = v; }
    public String     getLocationName()   { return locationName; }
    public void       setLocationName(String v){ this.locationName = v; }
    public String     getMake()           { return make; }
    public void       setMake(String v)   { this.make = v; }
    public String     getModel()          { return model; }
    public void       setModel(String v)  { this.model = v; }
    public Integer    getModelYear()      { return modelYear; }
    public void       setModelYear(Integer v){ this.modelYear = v; }
    public String     getColor()          { return color; }
    public void       setColor(String v)  { this.color = v; }
    public String     getVin()            { return vin; }
    public void       setVin(String v)    { this.vin = v; }
    public String     getLicensePlate()   { return licensePlate; }
    public void       setLicensePlate(String v){ this.licensePlate = v; }
    public Long       getMileage()        { return mileage; }
    public void       setMileage(Long v)  { this.mileage = v; }
    public String     getFuelType()       { return fuelType; }
    public void       setFuelType(String v){ this.fuelType = v; }
    public String     getTransmission()   { return transmission; }
    public void       setTransmission(String v){ this.transmission = v; }
    public Integer    getSeats()          { return seats; }
    public void       setSeats(Integer v) { this.seats = v; }
    public String     getStatus()         { return status; }
    public void       setStatus(String v) { this.status = v; }
    public BigDecimal getDailyRate()      { return dailyRate; }
    public void       setDailyRate(BigDecimal v){ this.dailyRate = v; }
    public BigDecimal getDailyOverride()  { return dailyOverride; }
    public void       setDailyOverride(BigDecimal v){ this.dailyOverride = v; }
    public String     getDescription()    { return description; }
    public void       setDescription(String v){ this.description = v; }
    public LocalDate  getLastServiceDate(){ return lastServiceDate; }
    public void       setLastServiceDate(LocalDate v){ this.lastServiceDate = v; }
    public LocalDate  getInsuranceExpiry(){ return insuranceExpiry; }
    public void       setInsuranceExpiry(LocalDate v){ this.insuranceExpiry = v; }
    public String     getIsActive()       { return isActive; }
    public void       setIsActive(String v){ this.isActive = v; }
    public LocalDateTime getCreatedAt()   { return createdAt; }
    public void       setCreatedAt(LocalDateTime v){ this.createdAt = v; }
    public LocalDateTime getUpdatedAt()   { return updatedAt; }
    public void       setUpdatedAt(LocalDateTime v){ this.updatedAt = v; }

    public String getDisplayName() {
        return make + " " + model + " " + modelYear + " (" + licensePlate + ")";
    }
}
