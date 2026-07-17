-- =============================================================================
-- CAR RENTAL SYSTEM - SEED DATA
-- =============================================================================

-- Locations
INSERT INTO locations (location_id, location_name, location_code, phone, email, operating_hours)
VALUES (7001, 'Downtown Branch',       'DT-01', '555-100-1001', 'downtown@carrental.com',  'Mon-Sun 7AM-10PM');
INSERT INTO locations (location_id, location_name, location_code, phone, email, operating_hours)
VALUES (7002, 'Airport Terminal A',    'AP-01', '555-100-1002', 'airport@carrental.com',   '24/7');
INSERT INTO locations (location_id, location_name, location_code, phone, email, operating_hours)
VALUES (7003, 'North Side Location',   'NS-01', '555-100-1003', 'northside@carrental.com', 'Mon-Sat 8AM-8PM');

-- Vehicle Categories
INSERT INTO vehicle_categories (category_name, description, daily_rate, weekly_rate, monthly_rate, deposit_amount)
VALUES ('Economy',   'Small fuel-efficient cars',       45.00,  270.00,  900.00,  300.00);
INSERT INTO vehicle_categories (category_name, description, daily_rate, weekly_rate, monthly_rate, deposit_amount)
VALUES ('Compact',   'Slightly larger compact cars',    55.00,  330.00, 1100.00,  350.00);
INSERT INTO vehicle_categories (category_name, description, daily_rate, weekly_rate, monthly_rate, deposit_amount)
VALUES ('SUV',       'Sport utility vehicles',          85.00,  510.00, 1700.00,  500.00);
INSERT INTO vehicle_categories (category_name, description, daily_rate, weekly_rate, monthly_rate, deposit_amount)
VALUES ('Luxury',    'Premium luxury vehicles',        150.00,  900.00, 3000.00, 1000.00);
INSERT INTO vehicle_categories (category_name, description, daily_rate, weekly_rate, monthly_rate, deposit_amount)
VALUES ('Electric',  'Zero-emission electric vehicles', 75.00,  450.00, 1500.00,  400.00);
INSERT INTO vehicle_categories (category_name, description, daily_rate, weekly_rate, monthly_rate, deposit_amount)
VALUES ('Van',       'Cargo and passenger vans',        95.00,  570.00, 1900.00,  600.00);

-- Employees
INSERT INTO employees (employee_id, location_id, first_name, last_name, email, job_title, salary, hire_date)
VALUES (6001, 7001, 'Sarah',   'Johnson',  'sjohnson@carrental.com',  'Branch Manager',      75000, DATE '2020-03-15');
INSERT INTO employees (employee_id, location_id, first_name, last_name, email, job_title, salary, hire_date, manager_id)
VALUES (6002, 7001, 'Mike',    'Peters',   'mpeters@carrental.com',   'Rental Agent',        42000, DATE '2021-06-01', 6001);
INSERT INTO employees (employee_id, location_id, first_name, last_name, email, job_title, salary, hire_date, manager_id)
VALUES (6003, 7002, 'Linda',   'Torres',   'ltorres@carrental.com',   'Branch Manager',      78000, DATE '2019-11-10', NULL);
INSERT INTO employees (employee_id, location_id, first_name, last_name, email, job_title, salary, hire_date, manager_id)
VALUES (6004, 7002, 'James',   'Wong',     'jwong@carrental.com',     'Rental Agent',        41000, DATE '2022-02-20', 6003);

-- Vehicles
INSERT INTO vehicles (vehicle_id, category_id, location_id, make, model, model_year, color, vin, license_plate, fuel_type, transmission, seats, status)
VALUES (2001, 1, 7001, 'Toyota',    'Corolla',    2022, 'Silver',  'JTDBL40E299999001', 'ABC-1001', 'GASOLINE', 'AUTOMATIC', 5, 'AVAILABLE');
INSERT INTO vehicles (vehicle_id, category_id, location_id, make, model, model_year, color, vin, license_plate, fuel_type, transmission, seats, status)
VALUES (2002, 1, 7001, 'Honda',     'Civic',      2023, 'Blue',    'JHMFC1F35PX999002', 'ABC-1002', 'GASOLINE', 'AUTOMATIC', 5, 'AVAILABLE');
INSERT INTO vehicles (vehicle_id, category_id, location_id, make, model, model_year, color, vin, license_plate, fuel_type, transmission, seats, status)
VALUES (2003, 3, 7002, 'Ford',      'Explorer',   2023, 'Black',   '1FMHK8D85BGA99003', 'XYZ-2001', 'GASOLINE', 'AUTOMATIC', 7, 'AVAILABLE');
INSERT INTO vehicles (vehicle_id, category_id, location_id, make, model, model_year, color, vin, license_plate, fuel_type, transmission, seats, status)
VALUES (2004, 3, 7002, 'Chevrolet', 'Tahoe',      2022, 'White',   '1GNSKBKC1NR999004', 'XYZ-2002', 'GASOLINE', 'AUTOMATIC', 8, 'AVAILABLE');
INSERT INTO vehicles (vehicle_id, category_id, location_id, make, model, model_year, color, vin, license_plate, fuel_type, transmission, seats, status)
VALUES (2005, 4, 7001, 'BMW',       '5 Series',   2024, 'Midnight Blue', 'WBA53BH07PCN99005', 'LUX-3001', 'GASOLINE', 'AUTOMATIC', 5, 'AVAILABLE');
INSERT INTO vehicles (vehicle_id, category_id, location_id, make, model, model_year, color, vin, license_plate, fuel_type, transmission, seats, status)
VALUES (2006, 5, 7003, 'Tesla',     'Model 3',    2024, 'Pearl White', '5YJ3E1EA8PF999006', 'EV-4001', 'ELECTRIC', 'AUTOMATIC', 5, 'AVAILABLE');
INSERT INTO vehicles (vehicle_id, category_id, location_id, make, model, model_year, color, vin, license_plate, fuel_type, transmission, seats, status)
VALUES (2007, 2, 7003, 'Nissan',    'Altima',     2022, 'Red',     '1N4AL3AP8JC999007', 'ABC-1003', 'GASOLINE', 'AUTOMATIC', 5, 'AVAILABLE');

-- Customers
INSERT INTO customers (customer_id, first_name, last_name, email, license_number, license_expiry, date_of_birth, loyalty_points, tier)
VALUES (1001, 'Alice',   'Brown',    'alice.brown@email.com',    'DL-CA-100001', DATE '2026-05-15', DATE '1988-07-22', 1250, 'SILVER');
INSERT INTO customers (customer_id, first_name, last_name, email, license_number, license_expiry, date_of_birth, loyalty_points, tier)
VALUES (1002, 'Bob',     'Smith',    'bob.smith@email.com',      'DL-NY-200002', DATE '2025-09-30', DATE '1975-03-10', 3800, 'GOLD');
INSERT INTO customers (customer_id, first_name, last_name, email, license_number, license_expiry, date_of_birth, loyalty_points, tier)
VALUES (1003, 'Carol',   'Williams', 'carol.w@email.com',        'DL-TX-300003', DATE '2027-01-20', DATE '1992-11-05', 5200, 'PLATINUM');
INSERT INTO customers (customer_id, first_name, last_name, email, license_number, license_expiry, date_of_birth, loyalty_points, tier)
VALUES (1004, 'David',   'Lee',      'dlee@email.com',           'DL-FL-400004', DATE '2026-12-01', DATE '1980-06-15', 300,  'BRONZE');
INSERT INTO customers (customer_id, first_name, last_name, email, license_number, license_expiry, date_of_birth, loyalty_points, tier)
VALUES (1005, 'Emma',    'Davis',    'emma.davis@email.com',     'DL-WA-500005', DATE '2025-08-22', DATE '1995-02-28', 780,  'SILVER');

-- Promo Codes
INSERT INTO promo_codes (promo_code, description, discount_type, discount_value, min_days, max_uses, valid_from, valid_to)
VALUES ('SUMMER24', 'Summer 2024 10% off',      'PERCENT', 10, 2, 500,  DATE '2024-06-01', DATE '2024-08-31');
INSERT INTO promo_codes (promo_code, description, discount_type, discount_value, min_days, max_uses, valid_from, valid_to)
VALUES ('FLAT50',   '$50 flat discount',         'FIXED',   50, 3, 200,  DATE '2024-01-01', DATE '2025-12-31');
INSERT INTO promo_codes (promo_code, description, discount_type, discount_value, min_days, max_uses, valid_from, valid_to)
VALUES ('LOYALTY15','Loyalty member 15% off',    'PERCENT', 15, 1, NULL, DATE '2024-01-01', DATE '2025-12-31');

-- Historical Rentals (completed - for reporting queries)
INSERT INTO rentals (rental_id, customer_id, vehicle_id, pickup_location, dropoff_location,
                     actual_pickup, actual_dropoff, odometer_out, odometer_in,
                     fuel_level_out, fuel_level_in, base_charge, fuel_charge,
                     damage_charge, late_fee, total_charge, status, employee_out, employee_in)
VALUES (4001, 1001, 2001, 7001, 7001,
        TIMESTAMP '2024-01-10 09:00:00', TIMESTAMP '2024-01-15 10:30:00',
        15000, 15320, 100, 80, 225.00, 60.00, 0, 0, 285.00, 'COMPLETED', 6002, 6002);

INSERT INTO rentals (rental_id, customer_id, vehicle_id, pickup_location, dropoff_location,
                     actual_pickup, actual_dropoff, odometer_out, odometer_in,
                     fuel_level_out, fuel_level_in, base_charge, fuel_charge,
                     damage_charge, late_fee, total_charge, status, employee_out, employee_in)
VALUES (4002, 1002, 2003, 7002, 7002,
        TIMESTAMP '2024-02-05 14:00:00', TIMESTAMP '2024-02-12 14:00:00',
        28000, 28650, 100, 100, 595.00, 0, 0, 0, 595.00, 'COMPLETED', 6004, 6004);

INSERT INTO rentals (rental_id, customer_id, vehicle_id, pickup_location, dropoff_location,
                     actual_pickup, actual_dropoff, odometer_out, odometer_in,
                     fuel_level_out, fuel_level_in, base_charge, fuel_charge,
                     damage_charge, late_fee, total_charge, status, employee_out, employee_in)
VALUES (4003, 1003, 2005, 7001, 7002,
        TIMESTAMP '2024-03-01 10:00:00', TIMESTAMP '2024-03-08 10:00:00',
        5000, 5450, 100, 90, 1050.00, 30.00, 0, 0, 1080.00, 'COMPLETED', 6002, 6004);

INSERT INTO rentals (rental_id, customer_id, vehicle_id, pickup_location, dropoff_location,
                     actual_pickup, actual_dropoff, odometer_out, odometer_in,
                     fuel_level_out, fuel_level_in, base_charge, fuel_charge,
                     damage_charge, late_fee, total_charge, status, employee_out, employee_in)
VALUES (4004, 1001, 2006, 7003, 7003,
        TIMESTAMP '2024-04-10 08:00:00', TIMESTAMP '2024-04-14 09:00:00',
        12000, 12280, 100, 100, 300.00, 0, 0, 0, 300.00, 'COMPLETED', 6002, 6002);

-- Payments
INSERT INTO payments (payment_id, rental_id, customer_id, amount, payment_method, transaction_ref, status, currency_code)
VALUES (5001, 4001, 1001, 285.00, 'CREDIT_CARD',  'TXN-CC-2024010001', 'COMPLETED', 'USD');
INSERT INTO payments (payment_id, rental_id, customer_id, amount, payment_method, transaction_ref, status, currency_code)
VALUES (5002, 4002, 1002, 595.00, 'DEBIT_CARD',   'TXN-DC-2024020002', 'COMPLETED', 'USD');
INSERT INTO payments (payment_id, rental_id, customer_id, amount, payment_method, transaction_ref, status, currency_code)
VALUES (5003, 4003, 1003, 1080.00,'CREDIT_CARD',  'TXN-CC-2024030003', 'COMPLETED', 'USD');
INSERT INTO payments (payment_id, rental_id, customer_id, amount, payment_method, transaction_ref, status, currency_code)
VALUES (5004, 4004, 1001, 300.00, 'DIGITAL_WALLET','TXN-DW-2024040004','COMPLETED', 'USD');

COMMIT;
