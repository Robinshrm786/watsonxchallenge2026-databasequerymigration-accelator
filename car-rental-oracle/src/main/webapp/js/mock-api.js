/**
 * MOCK API — Car Rental System
 * Intercepts all fetch() calls to /car-rental/api/* and returns
 * realistic sample data so the UI works without a Java/Oracle backend.
 *
 * To disable and use the real API:
 *   Remove the <script src="js/mock-api.js"> line from index.html
 */
(function () {
    'use strict';

    // ----------------------------------------------------------------
    // IN-MEMORY DATA STORE  (simulates Oracle tables)
    // ----------------------------------------------------------------
    const DB = {
        locations: [
            { location_id: 7001, location_name: 'Downtown Branch',     location_code: 'DT-01' },
            { location_id: 7002, location_name: 'Airport Terminal A',  location_code: 'AP-01' },
            { location_id: 7003, location_name: 'North Side Location', location_code: 'NS-01' }
        ],

        categories: [
            { category_id: 1, category_name: 'Economy',  daily_rate: 45.00 },
            { category_id: 2, category_name: 'Compact',  daily_rate: 55.00 },
            { category_id: 3, category_name: 'SUV',      daily_rate: 85.00 },
            { category_id: 4, category_name: 'Luxury',   daily_rate: 150.00 },
            { category_id: 5, category_name: 'Electric', daily_rate: 75.00 },
            { category_id: 6, category_name: 'Van',      daily_rate: 95.00 }
        ],

        vehicles: [
            { vehicleId: 2001, make: 'Toyota',    model: 'Corolla',  modelYear: 2022, color: 'Silver',       licensePlate: 'ABC-1001', categoryId: 1, categoryName: 'Economy',  fuelType: 'GASOLINE', transmission: 'AUTOMATIC', seats: 5, status: 'AVAILABLE', dailyRate: 45.00, locationId: 7001, locationName: 'Downtown Branch',     insuranceExpiry: '2025-12-01', displayName: 'Toyota Corolla 2022 (ABC-1001)' },
            { vehicleId: 2002, make: 'Honda',     model: 'Civic',    modelYear: 2023, color: 'Blue',         licensePlate: 'ABC-1002', categoryId: 1, categoryName: 'Economy',  fuelType: 'GASOLINE', transmission: 'AUTOMATIC', seats: 5, status: 'AVAILABLE', dailyRate: 45.00, locationId: 7001, locationName: 'Downtown Branch',     insuranceExpiry: '2026-03-15', displayName: 'Honda Civic 2023 (ABC-1002)' },
            { vehicleId: 2003, make: 'Ford',      model: 'Explorer', modelYear: 2023, color: 'Black',        licensePlate: 'XYZ-2001', categoryId: 3, categoryName: 'SUV',      fuelType: 'GASOLINE', transmission: 'AUTOMATIC', seats: 7, status: 'RENTED',    dailyRate: 85.00, locationId: 7002, locationName: 'Airport Terminal A',  insuranceExpiry: '2026-06-30', displayName: 'Ford Explorer 2023 (XYZ-2001)' },
            { vehicleId: 2004, make: 'Chevrolet', model: 'Tahoe',    modelYear: 2022, color: 'White',        licensePlate: 'XYZ-2002', categoryId: 3, categoryName: 'SUV',      fuelType: 'GASOLINE', transmission: 'AUTOMATIC', seats: 8, status: 'AVAILABLE', dailyRate: 85.00, locationId: 7002, locationName: 'Airport Terminal A',  insuranceExpiry: '2025-09-20', displayName: 'Chevrolet Tahoe 2022 (XYZ-2002)' },
            { vehicleId: 2005, make: 'BMW',       model: '5 Series', modelYear: 2024, color: 'Midnight Blue',licensePlate: 'LUX-3001', categoryId: 4, categoryName: 'Luxury',   fuelType: 'GASOLINE', transmission: 'AUTOMATIC', seats: 5, status: 'AVAILABLE', dailyRate: 150.00,locationId: 7001, locationName: 'Downtown Branch',     insuranceExpiry: '2026-11-01', displayName: 'BMW 5 Series 2024 (LUX-3001)' },
            { vehicleId: 2006, make: 'Tesla',     model: 'Model 3',  modelYear: 2024, color: 'Pearl White',  licensePlate: 'EV-4001',  categoryId: 5, categoryName: 'Electric', fuelType: 'ELECTRIC', transmission: 'AUTOMATIC', seats: 5, status: 'AVAILABLE', dailyRate: 75.00, locationId: 7003, locationName: 'North Side Location', insuranceExpiry: '2026-08-15', displayName: 'Tesla Model 3 2024 (EV-4001)' },
            { vehicleId: 2007, make: 'Nissan',    model: 'Altima',   modelYear: 2022, color: 'Red',          licensePlate: 'ABC-1003', categoryId: 2, categoryName: 'Compact',  fuelType: 'GASOLINE', transmission: 'AUTOMATIC', seats: 5, status: 'MAINTENANCE',dailyRate: 55.00, locationId: 7003, locationName: 'North Side Location', insuranceExpiry: '2025-07-10', displayName: 'Nissan Altima 2022 (ABC-1003)' },
            { vehicleId: 2008, make: 'Toyota',    model: 'Sienna',   modelYear: 2023, color: 'Graphite',     licensePlate: 'VAN-5001', categoryId: 6, categoryName: 'Van',      fuelType: 'HYBRID',   transmission: 'AUTOMATIC', seats: 8, status: 'AVAILABLE', dailyRate: 95.00, locationId: 7002, locationName: 'Airport Terminal A',  insuranceExpiry: '2026-04-30', displayName: 'Toyota Sienna 2023 (VAN-5001)' }
        ],

        customers: [
            { customerId: 1001, firstName: 'Alice',   lastName: 'Brown',    fullName: 'Alice Brown',    email: 'alice.brown@email.com',  licenseNumber: 'DL-CA-100001', licenseExpiry: '2026-05-15', dateOfBirth: '1988-07-22', age: 36, loyaltyPoints: 1250, tier: 'SILVER',   isActive: 'Y', createdAt: '2022-03-10 09:00:00', updatedAt: '2024-04-14 08:30:00' },
            { customerId: 1002, firstName: 'Bob',     lastName: 'Smith',    fullName: 'Bob Smith',      email: 'bob.smith@email.com',    licenseNumber: 'DL-NY-200002', licenseExpiry: '2025-09-30', dateOfBirth: '1975-03-10', age: 49, loyaltyPoints: 3800, tier: 'GOLD',     isActive: 'Y', createdAt: '2021-08-22 14:00:00', updatedAt: '2024-02-12 14:20:00' },
            { customerId: 1003, firstName: 'Carol',   lastName: 'Williams', fullName: 'Carol Williams', email: 'carol.w@email.com',      licenseNumber: 'DL-TX-300003', licenseExpiry: '2027-01-20', dateOfBirth: '1992-11-05', age: 31, loyaltyPoints: 5200, tier: 'PLATINUM', isActive: 'Y', createdAt: '2020-11-15 11:00:00', updatedAt: '2024-03-08 10:15:00' },
            { customerId: 1004, firstName: 'David',   lastName: 'Lee',      fullName: 'David Lee',      email: 'dlee@email.com',         licenseNumber: 'DL-FL-400004', licenseExpiry: '2026-12-01', dateOfBirth: '1980-06-15', age: 44, loyaltyPoints: 300,  tier: 'BRONZE',   isActive: 'Y', createdAt: '2023-06-01 10:00:00', updatedAt: '2023-06-01 10:00:00' },
            { customerId: 1005, firstName: 'Emma',    lastName: 'Davis',    fullName: 'Emma Davis',     email: 'emma.davis@email.com',   licenseNumber: 'DL-WA-500005', licenseExpiry: '2025-08-22', dateOfBirth: '1995-02-28', age: 29, loyaltyPoints: 780,  tier: 'SILVER',   isActive: 'Y', createdAt: '2023-01-20 16:30:00', updatedAt: '2024-01-18 09:00:00' },
            { customerId: 1006, firstName: 'James',   lastName: 'Wilson',   fullName: 'James Wilson',   email: 'j.wilson@email.com',     licenseNumber: 'DL-CA-600006', licenseExpiry: '2027-03-10', dateOfBirth: '1990-05-12', age: 34, loyaltyPoints: 4600, tier: 'GOLD',     isActive: 'Y', createdAt: '2021-02-14 08:00:00', updatedAt: '2024-05-01 12:00:00' },
            { customerId: 1007, firstName: 'Sophia',  lastName: 'Martinez', fullName: 'Sophia Martinez',email: 'sophia.m@email.com',     licenseNumber: 'DL-NY-700007', licenseExpiry: '2028-07-25', dateOfBirth: '1998-09-03', age: 26, loyaltyPoints: 150,  tier: 'BRONZE',   isActive: 'N', createdAt: '2024-01-05 10:00:00', updatedAt: '2024-06-01 09:00:00' }
        ],

        rentals: [
            { rentalId: 4001, customerId: 1001, customerName: 'Alice Brown',    vehicleId: 2001, vehicleInfo: 'Toyota Corolla (2022)',    licensePlate: 'ABC-1001', pickupLocation: 7001, pickupLocationName: 'Downtown Branch',    dropoffLocation: 7001, dropoffLocationName: 'Downtown Branch',    actualPickup: '2024-06-01 09:00:00', actualDropoff: null, odometerOut: 15000, fuelLevelOut: 100, baseCharge: 225.00, fuelCharge: 0, damageCharge: 0, lateFee: 0, totalCharge: null, status: 'ACTIVE' },
            { rentalId: 4002, customerId: 1002, customerName: 'Bob Smith',      vehicleId: 2003, vehicleInfo: 'Ford Explorer (2023)',     licensePlate: 'XYZ-2001', pickupLocation: 7002, pickupLocationName: 'Airport Terminal A', dropoffLocation: 7002, dropoffLocationName: 'Airport Terminal A', actualPickup: '2024-06-03 14:00:00', actualDropoff: null, odometerOut: 28000, fuelLevelOut: 100, baseCharge: 595.00, fuelCharge: 0, damageCharge: 0, lateFee: 0, totalCharge: null, status: 'ACTIVE' },
            { rentalId: 4003, customerId: 1003, customerName: 'Carol Williams', vehicleId: 2005, vehicleInfo: 'BMW 5 Series (2024)',     licensePlate: 'LUX-3001', pickupLocation: 7001, pickupLocationName: 'Downtown Branch',    dropoffLocation: 7002, dropoffLocationName: 'Airport Terminal A', actualPickup: '2024-06-05 10:00:00', actualDropoff: null, odometerOut: 5000,  fuelLevelOut: 100, baseCharge: 1050.00,fuelCharge: 0, damageCharge: 0, lateFee: 0, totalCharge: null, status: 'ACTIVE' }
        ],

        completedRentals: [
            { rentalId: 3001, customerId: 1001, vehicleId: 2001, vehicle: 'Toyota Corolla', licensePlate: 'ABC-1001', actualPickup: '2024-01-10 09:00:00', actualDropoff: '2024-01-15 10:30:00', totalCharge: 285.00, runningTotal: 285.00,  chargeRank: 3 },
            { rentalId: 3002, customerId: 1001, vehicleId: 2006, vehicle: 'Tesla Model 3',  licensePlate: 'EV-4001',  actualPickup: '2024-04-10 08:00:00', actualDropoff: '2024-04-14 09:00:00', totalCharge: 300.00, runningTotal: 585.00,  chargeRank: 2 },
            { rentalId: 3003, customerId: 1001, vehicleId: 2005, vehicle: 'BMW 5 Series',   licensePlate: 'LUX-3001', actualPickup: '2024-05-01 10:00:00', actualDropoff: '2024-05-08 12:00:00', totalCharge: 1050.00,runningTotal: 1635.00, chargeRank: 1 },
            { rentalId: 3004, customerId: 1002, vehicleId: 2003, vehicle: 'Ford Explorer',  licensePlate: 'XYZ-2001', actualPickup: '2024-02-05 14:00:00', actualDropoff: '2024-02-12 14:00:00', totalCharge: 595.00, runningTotal: 595.00,  chargeRank: 1 },
            { rentalId: 3005, customerId: 1003, vehicleId: 2005, vehicle: 'BMW 5 Series',   licensePlate: 'LUX-3001', actualPickup: '2024-03-01 10:00:00', actualDropoff: '2024-03-08 10:00:00', totalCharge: 1080.00,runningTotal: 1080.00, chargeRank: 1 }
        ],

        nextRentalId: 4010,
        nextVehicleId: 2010,
        nextCustomerId: 1010
    };

    // ----------------------------------------------------------------
    // ROUTER  — maps URL patterns to handler functions
    // ----------------------------------------------------------------
    const routes = [
        { match: (u, m) => u.includes('/vehicles') && m === 'GET',  handler: handleVehiclesGET  },
        { match: (u, m) => u.includes('/vehicles') && m === 'POST', handler: handleVehiclesPOST },
        { match: (u, m) => u.includes('/customers') && m === 'GET',    handler: handleCustomersGET    },
        { match: (u, m) => u.includes('/customers') && m === 'POST',   handler: handleCustomersPOST   },
        { match: (u, m) => u.includes('/customers') && m === 'PUT',    handler: handleCustomersPUT    },
        { match: (u, m) => u.includes('/customers') && m === 'DELETE', handler: handleCustomersDELETE },
        { match: (u, m) => u.includes('/rentals') && m === 'GET',  handler: handleRentalsGET  },
        { match: (u, m) => u.includes('/rentals') && m === 'POST', handler: handleRentalsPOST },
        { match: (u, m) => u.includes('/rentals') && m === 'PUT',  handler: handleRentalsPUT  }
    ];

    // ----------------------------------------------------------------
    // FETCH INTERCEPTOR
    // ----------------------------------------------------------------
    const realFetch = window.fetch.bind(window);
    window.fetch = function (url, options = {}) {
        const urlStr  = String(url);
        const method  = (options.method || 'GET').toUpperCase();

        // Only intercept calls that go to /api/
        if (!urlStr.includes('/api/')) return realFetch(url, options);

        const route = routes.find(r => r.match(urlStr, method));
        if (!route) {
            return mockResp({ success: false, error: 'Mock: no route for ' + method + ' ' + urlStr }, 404);
        }

        const params  = parseParams(urlStr);
        const body    = parseBody(options.body);
        const result  = route.handler(params, body, urlStr);
        return mockResp(result);
    };

    // ----------------------------------------------------------------
    // VEHICLE HANDLERS
    // ----------------------------------------------------------------
    function handleVehiclesGET(params) {
        if (params.action === 'utilization' && params.id) {
            return { success: true, vehicleId: +params.id, utilizationPct: (Math.random() * 60 + 20).toFixed(1) };
        }
        if (params.action === 'revenue') {
            return { success: true, columns: ['period', 'rentals', 'revenue'], rows: mockRevenueRows() };
        }
        if (params.id) {
            const v = DB.vehicles.find(x => x.vehicleId === +params.id);
            return v ? { success: true, data: v } : { success: false, error: 'Not found' };
        }
        let list = DB.vehicles.slice();
        if (params.search) {
            const kw = params.search.toLowerCase();
            list = list.filter(v =>
                v.make.toLowerCase().includes(kw) ||
                v.model.toLowerCase().includes(kw) ||
                v.licensePlate.toLowerCase().includes(kw));
        }
        if (params.categoryId) list = list.filter(v => v.categoryId === +params.categoryId);
        // default: only AVAILABLE
        if (!params.search && !params.id) list = list.filter(v => v.status === 'AVAILABLE');
        return { success: true, data: list };
    }

    function handleVehiclesPOST(params, body) {
        const newV = {
            vehicleId:    DB.nextVehicleId++,
            make:         body.make         || 'Unknown',
            model:        body.model        || 'Unknown',
            modelYear:    +body.modelYear   || 2024,
            color:        body.color        || '',
            licensePlate: body.licensePlate || '',
            categoryId:   +body.categoryId  || 1,
            categoryName: DB.categories.find(c => c.category_id === +body.categoryId)?.category_name || 'Economy',
            fuelType:     body.fuelType     || 'GASOLINE',
            transmission: body.transmission || 'AUTOMATIC',
            seats:        +body.seats       || 5,
            status:       'AVAILABLE',
            dailyRate:    body.dailyOverride ? +body.dailyOverride : 45.00,
            locationId:   body.locationId   ? +body.locationId : 7001,
            locationName: 'Downtown Branch',
            insuranceExpiry: '2026-12-31',
            displayName:  (body.make||'') + ' ' + (body.model||'') + ' ' + (body.modelYear||'')
        };
        DB.vehicles.push(newV);
        return { success: true, vehicleId: newV.vehicleId };
    }

    // ----------------------------------------------------------------
    // CUSTOMER HANDLERS
    // ----------------------------------------------------------------
    function handleCustomersGET(params) {
        if (params.id && params.action === 'history') {
            const rows = DB.completedRentals
                .filter(r => r.customerId === +params.id)
                .map(r => [r.rentalId, r.vehicle, r.licensePlate, r.actualPickup, r.actualDropoff, r.totalCharge, r.runningTotal, r.chargeRank]);
            return { success: true, columns: ['rentalId','vehicle','licensePlate','pickup','dropoff','charge','runningTotal','rank'], rows };
        }
        if (params.id) {
            const c = DB.customers.find(x => x.customerId === +params.id);
            return c ? { success: true, data: c } : { success: false, error: 'Not found' };
        }
        let list = DB.customers.slice();
        if (params.search) {
            const kw = params.search.toLowerCase();
            list = list.filter(c =>
                c.fullName.toLowerCase().includes(kw) ||
                c.email.toLowerCase().includes(kw) ||
                c.licenseNumber.toLowerCase().includes(kw));
        } else {
            list = list.filter(c => c.isActive === 'Y');
        }
        return { success: true, data: list };
    }

    function handleCustomersPOST(params, body) {
        const newC = {
            customerId:    DB.nextCustomerId++,
            firstName:     body.firstName     || '',
            lastName:      body.lastName      || '',
            fullName:      (body.firstName||'') + ' ' + (body.lastName||''),
            email:         body.email         || '',
            licenseNumber: body.licenseNumber || '',
            licenseExpiry: body.licenseExpiry || '',
            dateOfBirth:   body.dateOfBirth   || '',
            age:           calcAge(body.dateOfBirth),
            loyaltyPoints: 0,
            tier:          'BRONZE',
            isActive:      'Y',
            createdAt:     now(),
            updatedAt:     now()
        };
        DB.customers.push(newC);
        return { success: true, customerId: newC.customerId };
    }

    function handleCustomersPUT(params, body) {
        const c = DB.customers.find(x => x.customerId === +body.customerId);
        if (!c) return { success: false, error: 'Customer not found' };
        Object.assign(c, {
            firstName:     body.firstName     || c.firstName,
            lastName:      body.lastName      || c.lastName,
            fullName:      (body.firstName||c.firstName) + ' ' + (body.lastName||c.lastName),
            email:         body.email         || c.email,
            licenseNumber: body.licenseNumber || c.licenseNumber,
            licenseExpiry: body.licenseExpiry || c.licenseExpiry,
            dateOfBirth:   body.dateOfBirth   || c.dateOfBirth,
            loyaltyPoints: body.loyaltyPoints ? +body.loyaltyPoints : c.loyaltyPoints,
            updatedAt:     now()
        });
        return { success: true, message: 'Customer updated' };
    }

    function handleCustomersDELETE(params) {
        const c = DB.customers.find(x => x.customerId === +params.id);
        if (!c) return { success: false, error: 'Not found' };
        c.isActive  = 'N';
        c.updatedAt = now();
        return { success: true, message: 'Customer deactivated' };
    }

    // ----------------------------------------------------------------
    // RENTAL HANDLERS
    // ----------------------------------------------------------------
    function handleRentalsGET(params) {
        if (params.action === 'dashboard') {
            return {
                success: true,
                stats: [
                    { status: 'ACTIVE',    count: 3,  totalRevenue: null,    avgCharge: null,   maxCharge: null   },
                    { status: 'COMPLETED', count: 28, totalRevenue: 14850.00, avgCharge: 530.36, maxCharge: 1850.00 },
                    { status: 'DISPUTED',  count: 1,  totalRevenue: 320.00,  avgCharge: 320.00, maxCharge: 320.00 }
                ]
            };
        }
        if (params.action === 'overdue') {
            // Rentals picked up >3 days ago still active
            const overdue = DB.rentals.filter(r => r.status === 'ACTIVE').map(r => ({
                ...r, vehicleInfo: r.vehicleInfo
            }));
            return { success: true, data: overdue };
        }
        if (params.action === 'report') {
            return {
                success: true,
                columns: ['period','rentals','total_revenue','avg_revenue','base_rev','fuel_rev','damage_rev','late_fees'],
                rows: mockReportRows()
            };
        }
        if (params.id) {
            const r = DB.rentals.find(x => x.rentalId === +params.id);
            return r ? { success: true, data: r } : { success: false, error: 'Not found' };
        }
        // Default: active rentals
        return { success: true, data: DB.rentals.filter(r => r.status === 'ACTIVE') };
    }

    function handleRentalsPOST(params, body) {
        if (body.action !== 'begin') return { success: false, error: 'Unknown action' };
        const reservationId = +body.reservationId;
        const vehicleId     = reservationId % 2 === 0 ? 2002 : 2006; // pick a vehicle
        const customer      = DB.customers.find(c => c.isActive === 'Y') || DB.customers[0];
        const vehicle       = DB.vehicles.find(v => v.vehicleId === vehicleId) || DB.vehicles[0];

        const newRental = {
            rentalId:            DB.nextRentalId++,
            reservationId,
            customerId:          customer.customerId,
            customerName:        customer.fullName,
            vehicleId:           vehicle.vehicleId,
            vehicleInfo:         vehicle.make + ' ' + vehicle.model + ' (' + vehicle.modelYear + ')',
            licensePlate:        vehicle.licensePlate,
            pickupLocation:      7001,
            pickupLocationName:  'Downtown Branch',
            dropoffLocation:     7001,
            dropoffLocationName: 'Downtown Branch',
            actualPickup:        now(),
            actualDropoff:       null,
            odometerOut:         +body.odometerOut || 0,
            fuelLevelOut:        100,
            baseCharge:          vehicle.dailyRate * 3,
            fuelCharge:          0,
            damageCharge:        0,
            lateFee:             0,
            totalCharge:         null,
            status:              'ACTIVE'
        };
        DB.rentals.push(newRental);
        // Mark vehicle rented
        vehicle.status = 'RENTED';
        return { success: true, rentalId: newRental.rentalId };
    }

    function handleRentalsPUT(params, body) {
        const rental = DB.rentals.find(r => r.rentalId === +body.rentalId);
        if (!rental) return { success: false, error: 'Rental not found: ' + body.rentalId };
        if (rental.status !== 'ACTIVE') return { success: false, error: 'Rental is not ACTIVE' };

        const odometerIn  = +body.odometerIn  || rental.odometerOut + 150;
        const fuelLevelIn = +body.fuelLevelIn || 100;
        const fuelCharge  = Math.max(0, (rental.fuelLevelOut - fuelLevelIn) * 3);
        const damageCharge= body.damageNotes && body.damageNotes.trim().length > 0 ? 250 : 0;
        const totalCharge = (rental.baseCharge || 0) + fuelCharge + damageCharge;

        Object.assign(rental, {
            status:        'COMPLETED',
            actualDropoff: now(),
            odometerIn,
            fuelLevelIn,
            fuelCharge,
            damageCharge,
            totalCharge,
            damageNotes:   body.damageNotes || null
        });

        // Free up vehicle
        const vehicle = DB.vehicles.find(v => v.vehicleId === rental.vehicleId);
        if (vehicle) vehicle.status = 'AVAILABLE';

        // Add loyalty points
        const customer = DB.customers.find(c => c.customerId === rental.customerId);
        if (customer) {
            customer.loyaltyPoints += Math.round(totalCharge);
            customer.tier = loyaltyTier(customer.loyaltyPoints);
        }

        return { success: true, message: 'Rental ' + rental.rentalId + ' completed. Total: $' + totalCharge.toFixed(2) };
    }

    // ----------------------------------------------------------------
    // HELPERS
    // ----------------------------------------------------------------
    function mockRevenueRows() {
        const months = ['2024-01','2024-02','2024-03','2024-04','2024-05','2024-06'];
        return months.map(m => [m, Math.floor(Math.random()*8)+3, +(Math.random()*3000+1200).toFixed(2)]);
    }

    function mockReportRows() {
        const months = ['2024-01','2024-02','2024-03','2024-04','2024-05','2024-06'];
        let grandTotal = 0;
        const rows = months.map(m => {
            const cnt = Math.floor(Math.random()*8)+3;
            const rev = +(Math.random()*3000+1500).toFixed(2);
            const base= +(rev * 0.75).toFixed(2);
            const fuel= +(rev * 0.08).toFixed(2);
            const dmg = +(rev * 0.05).toFixed(2);
            const late= +(rev * 0.02).toFixed(2);
            grandTotal += rev;
            return [m, cnt, rev, +(rev/cnt).toFixed(2), base, fuel, dmg, late];
        });
        rows.push(['TOTAL', rows.reduce((s,r) => s + r[1], 0), +grandTotal.toFixed(2), +(grandTotal/rows.length).toFixed(2), null, null, null, null]);
        return rows;
    }

    function parseParams(url) {
        const p = {};
        const idx = url.indexOf('?');
        if (idx < 0) return p;
        url.slice(idx + 1).split('&').forEach(pair => {
            const [k, v] = pair.split('=');
            if (k) p[decodeURIComponent(k)] = decodeURIComponent(v || '');
        });
        return p;
    }

    function parseBody(body) {
        if (!body) return {};
        try { return JSON.parse(body); } catch { return {}; }
    }

    function mockResp(data, status = 200) {
        return Promise.resolve(new Response(JSON.stringify(data), {
            status,
            headers: { 'Content-Type': 'application/json' }
        }));
    }

    function now() {
        return new Date().toISOString().replace('T', ' ').substring(0, 19);
    }

    function calcAge(dob) {
        if (!dob) return null;
        return Math.floor((new Date() - new Date(dob)) / (365.25 * 24 * 3600 * 1000));
    }

    function loyaltyTier(pts) {
        if (pts < 500)  return 'BRONZE';
        if (pts < 2000) return 'SILVER';
        if (pts < 5000) return 'GOLD';
        return 'PLATINUM';
    }

    console.log('%c[Mock API] Active — all fetch() calls to /api/ are intercepted', 'color:#0d6efd;font-weight:bold');
    console.log('%c[Mock API] To use real Oracle backend, remove mock-api.js from index.html', 'color:#57606a');

})();
