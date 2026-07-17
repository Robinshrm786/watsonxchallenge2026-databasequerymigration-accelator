package com.carrental.model;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Customer domain model mapping to the CUSTOMERS Oracle table.
 * Virtual columns (full_name, age) are read-only.
 */
public class Customer {

    private Long      customerId;
    private String    firstName;
    private String    lastName;
    private String    fullName;       // virtual column — read only
    private String    email;
    private String    licenseNumber;
    private LocalDate licenseExpiry;
    private LocalDate dateOfBirth;
    private Integer   age;           // virtual column — read only
    private Integer   loyaltyPoints;
    private String    tier;
    private String    notes;
    private String    isActive;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    // ---- Constructors ----
    public Customer() {}

    public Customer(String firstName, String lastName, String email,
                    String licenseNumber, LocalDate licenseExpiry, LocalDate dateOfBirth) {
        this.firstName     = firstName;
        this.lastName      = lastName;
        this.email         = email;
        this.licenseNumber = licenseNumber;
        this.licenseExpiry = licenseExpiry;
        this.dateOfBirth   = dateOfBirth;
        this.loyaltyPoints = 0;
        this.tier          = "BRONZE";
        this.isActive      = "Y";
    }

    // ---- Getters / Setters ----
    public Long      getCustomerId()    { return customerId; }
    public void      setCustomerId(Long v)  { this.customerId = v; }
    public String    getFirstName()     { return firstName; }
    public void      setFirstName(String v) { this.firstName = v; }
    public String    getLastName()      { return lastName; }
    public void      setLastName(String v)  { this.lastName = v; }
    public String    getFullName()      { return fullName; }
    public void      setFullName(String v)  { this.fullName = v; }
    public String    getEmail()         { return email; }
    public void      setEmail(String v)     { this.email = v; }
    public String    getLicenseNumber() { return licenseNumber; }
    public void      setLicenseNumber(String v) { this.licenseNumber = v; }
    public LocalDate getLicenseExpiry() { return licenseExpiry; }
    public void      setLicenseExpiry(LocalDate v) { this.licenseExpiry = v; }
    public LocalDate getDateOfBirth()   { return dateOfBirth; }
    public void      setDateOfBirth(LocalDate v)   { this.dateOfBirth = v; }
    public Integer   getAge()           { return age; }
    public void      setAge(Integer v)  { this.age = v; }
    public Integer   getLoyaltyPoints() { return loyaltyPoints; }
    public void      setLoyaltyPoints(Integer v) { this.loyaltyPoints = v; }
    public String    getTier()          { return tier; }
    public void      setTier(String v)  { this.tier = v; }
    public String    getNotes()         { return notes; }
    public void      setNotes(String v) { this.notes = v; }
    public String    getIsActive()      { return isActive; }
    public void      setIsActive(String v) { this.isActive = v; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void      setCreatedAt(LocalDateTime v) { this.createdAt = v; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void      setUpdatedAt(LocalDateTime v) { this.updatedAt = v; }

    @Override public String toString() {
        return "Customer{id=" + customerId + ", name=" + fullName + ", tier=" + tier + "}";
    }
}
