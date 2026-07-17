package com.carrental.model;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/** Maps to RENTALS table with joined denormalized fields for display. */
public class Rental {

    private Long         rentalId;
    private Long         reservationId;
    private Long         customerId;
    private String       customerName;
    private Long         vehicleId;
    private String       vehicleInfo;
    private Integer      pickupLocation;
    private String       pickupLocationName;
    private Integer      dropoffLocation;
    private String       dropoffLocationName;
    private LocalDateTime actualPickup;
    private LocalDateTime actualDropoff;
    private Long         odometerOut;
    private Long         odometerIn;
    private Long         milesDriven;   // virtual column
    private Integer      fuelLevelOut;
    private Integer      fuelLevelIn;
    private BigDecimal   baseCharge;
    private BigDecimal   fuelCharge;
    private BigDecimal   damageCharge;
    private BigDecimal   lateFee;
    private BigDecimal   totalCharge;
    private String       status;
    private Long         employeeOut;
    private Long         employeeIn;
    private String       damageNotes;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public Rental() {}

    // ---- Getters / Setters ----
    public Long          getRentalId()          { return rentalId; }
    public void          setRentalId(Long v)     { this.rentalId = v; }
    public Long          getReservationId()      { return reservationId; }
    public void          setReservationId(Long v){ this.reservationId = v; }
    public Long          getCustomerId()         { return customerId; }
    public void          setCustomerId(Long v)   { this.customerId = v; }
    public String        getCustomerName()       { return customerName; }
    public void          setCustomerName(String v){ this.customerName = v; }
    public Long          getVehicleId()          { return vehicleId; }
    public void          setVehicleId(Long v)    { this.vehicleId = v; }
    public String        getVehicleInfo()        { return vehicleInfo; }
    public void          setVehicleInfo(String v){ this.vehicleInfo = v; }
    public Integer       getPickupLocation()     { return pickupLocation; }
    public void          setPickupLocation(Integer v){ this.pickupLocation = v; }
    public String        getPickupLocationName() { return pickupLocationName; }
    public void          setPickupLocationName(String v){ this.pickupLocationName = v; }
    public Integer       getDropoffLocation()    { return dropoffLocation; }
    public void          setDropoffLocation(Integer v){ this.dropoffLocation = v; }
    public String        getDropoffLocationName(){ return dropoffLocationName; }
    public void          setDropoffLocationName(String v){ this.dropoffLocationName = v; }
    public LocalDateTime getActualPickup()       { return actualPickup; }
    public void          setActualPickup(LocalDateTime v){ this.actualPickup = v; }
    public LocalDateTime getActualDropoff()      { return actualDropoff; }
    public void          setActualDropoff(LocalDateTime v){ this.actualDropoff = v; }
    public Long          getOdometerOut()        { return odometerOut; }
    public void          setOdometerOut(Long v)  { this.odometerOut = v; }
    public Long          getOdometerIn()         { return odometerIn; }
    public void          setOdometerIn(Long v)   { this.odometerIn = v; }
    public Long          getMilesDriven()        { return milesDriven; }
    public void          setMilesDriven(Long v)  { this.milesDriven = v; }
    public Integer       getFuelLevelOut()       { return fuelLevelOut; }
    public void          setFuelLevelOut(Integer v){ this.fuelLevelOut = v; }
    public Integer       getFuelLevelIn()        { return fuelLevelIn; }
    public void          setFuelLevelIn(Integer v){ this.fuelLevelIn = v; }
    public BigDecimal    getBaseCharge()         { return baseCharge; }
    public void          setBaseCharge(BigDecimal v){ this.baseCharge = v; }
    public BigDecimal    getFuelCharge()         { return fuelCharge; }
    public void          setFuelCharge(BigDecimal v){ this.fuelCharge = v; }
    public BigDecimal    getDamageCharge()       { return damageCharge; }
    public void          setDamageCharge(BigDecimal v){ this.damageCharge = v; }
    public BigDecimal    getLateFee()            { return lateFee; }
    public void          setLateFee(BigDecimal v){ this.lateFee = v; }
    public BigDecimal    getTotalCharge()        { return totalCharge; }
    public void          setTotalCharge(BigDecimal v){ this.totalCharge = v; }
    public String        getStatus()             { return status; }
    public void          setStatus(String v)     { this.status = v; }
    public Long          getEmployeeOut()        { return employeeOut; }
    public void          setEmployeeOut(Long v)  { this.employeeOut = v; }
    public Long          getEmployeeIn()         { return employeeIn; }
    public void          setEmployeeIn(Long v)   { this.employeeIn = v; }
    public String        getDamageNotes()        { return damageNotes; }
    public void          setDamageNotes(String v){ this.damageNotes = v; }
    public LocalDateTime getCreatedAt()          { return createdAt; }
    public void          setCreatedAt(LocalDateTime v){ this.createdAt = v; }
    public LocalDateTime getUpdatedAt()          { return updatedAt; }
    public void          setUpdatedAt(LocalDateTime v){ this.updatedAt = v; }
}
