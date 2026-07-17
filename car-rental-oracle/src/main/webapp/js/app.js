'use strict';

// ============================================================
// CONFIGURATION — update BASE_URL if deployed differently
// ============================================================
const BASE_URL = '/car-rental/api';

// ============================================================
// NAVIGATION
// ============================================================
const PAGE_TITLES = {
    dashboard: 'Dashboard',
    vehicles:  'Vehicles',
    customers: 'Customers',
    rentals:   'Active Rentals',
    newrental: 'New Rental',
    returns:   'Return Vehicle',
    reports:   'Reports',
    overdue:   'Overdue Rentals'
};

document.querySelectorAll('.nav-item').forEach(item => {
    item.addEventListener('click', () => {
        const page = item.dataset.page;
        navigateTo(page);
    });
});

function navigateTo(page) {
    // Update nav highlight
    document.querySelectorAll('.nav-item').forEach(n =>
        n.classList.toggle('active', n.dataset.page === page));
    // Show/hide pages
    document.querySelectorAll('section.page').forEach(s =>
        s.classList.toggle('active', s.id === 'page-' + page));
    // Update topbar title
    document.getElementById('pageTitle').textContent = PAGE_TITLES[page] || page;

    // Auto-load data for the page
    switch (page) {
        case 'dashboard': loadDashboard();      break;
        case 'vehicles':  loadVehicles();        break;
        case 'customers': loadCustomers();       break;
        case 'rentals':   loadActiveRentals();   break;
        case 'overdue':   loadOverdue();         break;
        case 'reports':   initReportDates();     break;
    }
}

function toggleSidebar() {
    document.getElementById('sidebar').classList.toggle('open');
}

// ============================================================
// API HELPERS
// ============================================================
async function apiFetch(url, options = {}) {
    const res = await fetch(url, {
        headers: { 'Content-Type': 'application/json' },
        ...options
    });
    const data = await res.json();
    if (!data.success && !options.allowError) {
        throw new Error(data.error || 'API error');
    }
    return data;
}

function fmt(val) {
    if (val === null || val === undefined) return '—';
    return val;
}
function fmtMoney(val) {
    if (val === null || val === undefined || val === '') return '—';
    return '$' + Number(val).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}
function fmtDate(val) {
    if (!val) return '—';
    return String(val).replace('T', ' ').substring(0, 16);
}
function statusBadge(status) {
    const cls = {
        ACTIVE: 'active', COMPLETED: 'completed',
        AVAILABLE: 'avail', RENTED: 'rented', MAINTENANCE: 'maint'
    };
    return `<span class="badge badge-${cls[status] || ''}">${status}</span>`;
}
function tierBadge(tier) {
    return `<span class="badge badge-${(tier||'bronze').toLowerCase()}">${tier||'—'}</span>`;
}

// ============================================================
// DASHBOARD
// ============================================================
async function loadDashboard() {
    try {
        const [dashData, activeData, vehicleData] = await Promise.all([
            apiFetch(`${BASE_URL}/rentals?action=dashboard`),
            apiFetch(`${BASE_URL}/rentals`),
            apiFetch(`${BASE_URL}/vehicles`)
        ]);

        // KPIs
        const stats = dashData.stats || [];
        const active = (activeData.data || []).length;
        const vehicles = (vehicleData.data || []).length;
        let revenue = 0;
        stats.forEach(s => { if (s.status === 'COMPLETED') revenue += Number(s.totalRevenue || 0); });

        document.getElementById('kpiActive').textContent    = active;
        document.getElementById('kpiRevenue').textContent   = fmtMoney(revenue);
        document.getElementById('kpiVehicles').textContent  = vehicles;

        // Count customers from customer API
        const custData = await apiFetch(`${BASE_URL}/customers`);
        document.getElementById('kpiCustomers').textContent = (custData.data || []).length;

        // Dashboard table
        const tbody = document.getElementById('dashBody');
        tbody.innerHTML = '';
        stats.forEach(s => {
            tbody.innerHTML += `<tr>
                <td>${statusBadge(s.status)}</td>
                <td>${fmt(s.count)}</td>
                <td>${fmtMoney(s.totalRevenue)}</td>
                <td>${fmtMoney(s.avgCharge)}</td>
                <td>${fmtMoney(s.maxCharge)}</td>
            </tr>`;
        });

        // Recent rentals
        const recent = document.getElementById('recentBody');
        recent.innerHTML = '';
        (activeData.data || []).slice(0, 8).forEach(r => {
            recent.innerHTML += `<tr>
                <td>${r.rentalId}</td>
                <td>${fmt(r.customerName)}</td>
                <td>${fmt(r.vehicleInfo)}</td>
                <td>${fmtDate(r.actualPickup)}</td>
                <td>${fmt(r.pickupLocationName)}</td>
            </tr>`;
        });
    } catch (e) {
        showToast('Dashboard load error: ' + e.message, 'error');
    }
}

// ============================================================
// VEHICLES
// ============================================================
async function loadVehicles(search) {
    const keyword = document.getElementById('vehicleSearch')?.value?.trim();
    const catId   = document.getElementById('vehicleCatFilter')?.value;
    try {
        let url;
        if (keyword) {
            url = `${BASE_URL}/vehicles?search=${encodeURIComponent(keyword)}`;
        } else {
            url = `${BASE_URL}/vehicles?categoryId=${catId || ''}`;
        }
        const data = await apiFetch(url);
        const tbody = document.getElementById('vehicleBody');
        tbody.innerHTML = '';
        (data.data || []).forEach(v => {
            tbody.innerHTML += `<tr>
                <td>${v.vehicleId}</td>
                <td><strong>${v.make} ${v.model}</strong></td>
                <td>${v.modelYear}</td>
                <td>${fmt(v.categoryName)}</td>
                <td>${fmt(v.licensePlate)}</td>
                <td>${fmt(v.fuelType)}</td>
                <td>${fmt(v.seats)}</td>
                <td>${fmtMoney(v.dailyRate)}</td>
                <td>${statusBadge(v.status)}</td>
                <td>${fmt(v.locationName)}</td>
            </tr>`;
        });
    } catch (e) {
        showToast('Vehicles load error: ' + e.message, 'error');
    }
}

function searchVehicles() {
    clearTimeout(window._vSearch);
    window._vSearch = setTimeout(loadVehicles, 350);
}

async function saveVehicle() {
    const payload = {
        make:         document.getElementById('vm_make').value,
        model:        document.getElementById('vm_model').value,
        modelYear:    document.getElementById('vm_year').value,
        color:        document.getElementById('vm_color').value,
        vin:          document.getElementById('vm_vin').value,
        licensePlate: document.getElementById('vm_plate').value,
        categoryId:   document.getElementById('vm_category').value,
        fuelType:     document.getElementById('vm_fuel').value,
        transmission: document.getElementById('vm_trans').value,
        seats:        document.getElementById('vm_seats').value,
        dailyOverride:document.getElementById('vm_override').value || null
    };
    try {
        const res = await apiFetch(`${BASE_URL}/vehicles`, {
            method: 'POST',
            body: JSON.stringify(payload)
        });
        showToast('Vehicle saved! ID: ' + res.vehicleId, 'success');
        closeModal('vehicleModal');
        loadVehicles();
    } catch (e) {
        showToast('Save failed: ' + e.message, 'error');
    }
}

// ============================================================
// CUSTOMERS
// ============================================================
async function loadCustomers() {
    const keyword = document.getElementById('customerSearch')?.value?.trim();
    try {
        let url = keyword
            ? `${BASE_URL}/customers?search=${encodeURIComponent(keyword)}`
            : `${BASE_URL}/customers`;
        const data = await apiFetch(url);
        const tbody = document.getElementById('customerBody');
        tbody.innerHTML = '';
        (data.data || []).forEach(c => {
            tbody.innerHTML += `<tr>
                <td>${c.customerId}</td>
                <td><strong>${c.fullName || (c.firstName + ' ' + c.lastName)}</strong></td>
                <td>${fmt(c.email)}</td>
                <td>${fmt(c.licenseNumber)}</td>
                <td>${fmt(c.age)}</td>
                <td>${tierBadge(c.tier)}</td>
                <td>${fmt(c.loyaltyPoints)}</td>
                <td>${c.isActive === 'Y' ? '✅' : '❌'}</td>
                <td>
                  <button class="btn btn-sm btn-secondary"
                    onclick="viewHistory(${c.customerId},'${(c.fullName||'').replace(/'/g,"\\'")}')">
                    History
                  </button>
                  <button class="btn btn-sm btn-danger"
                    onclick="deleteCustomer(${c.customerId})">Delete</button>
                </td>
            </tr>`;
        });
    } catch (e) {
        showToast('Customers load error: ' + e.message, 'error');
    }
}

function searchCustomers() {
    clearTimeout(window._cSearch);
    window._cSearch = setTimeout(loadCustomers, 350);
}

async function saveCustomer() {
    const payload = {
        firstName:     document.getElementById('cm_first').value,
        lastName:      document.getElementById('cm_last').value,
        email:         document.getElementById('cm_email').value,
        licenseNumber: document.getElementById('cm_license').value,
        licenseExpiry: document.getElementById('cm_licexpiry').value,
        dateOfBirth:   document.getElementById('cm_dob').value,
        notes:         document.getElementById('cm_notes').value
    };
    try {
        const res = await apiFetch(`${BASE_URL}/customers`, {
            method: 'POST',
            body: JSON.stringify(payload)
        });
        showToast('Customer saved! ID: ' + res.customerId, 'success');
        closeModal('customerModal');
        loadCustomers();
    } catch (e) {
        showToast('Save failed: ' + e.message, 'error');
    }
}

async function deleteCustomer(id) {
    if (!confirm('Deactivate customer ' + id + '?')) return;
    try {
        await apiFetch(`${BASE_URL}/customers?id=${id}`, { method: 'DELETE' });
        showToast('Customer deactivated', 'success');
        loadCustomers();
    } catch (e) {
        showToast('Error: ' + e.message, 'error');
    }
}

async function viewHistory(customerId, name) {
    document.getElementById('historyCustomerName').textContent = name;
    try {
        const data = await apiFetch(`${BASE_URL}/customers?id=${customerId}&action=history`);
        const tbody = document.getElementById('historyBody');
        tbody.innerHTML = '';
        (data.rows || []).forEach(row => {
            tbody.innerHTML += `<tr>
                <td>${row[0]}</td>
                <td>${fmt(row[1])}</td>
                <td>${fmt(row[2])}</td>
                <td>${fmtDate(row[3])}</td>
                <td>${fmtDate(row[4])}</td>
                <td>${fmtMoney(row[5])}</td>
                <td>${fmtMoney(row[6])}</td>
                <td>#${row[7]}</td>
            </tr>`;
        });
        openModal('historyModal');
    } catch (e) {
        showToast('History error: ' + e.message, 'error');
    }
}

// ============================================================
// ACTIVE RENTALS
// ============================================================
async function loadActiveRentals() {
    try {
        const data = await apiFetch(`${BASE_URL}/rentals`);
        const tbody = document.getElementById('rentalBody');
        tbody.innerHTML = '';
        (data.data || []).forEach(r => {
            tbody.innerHTML += `<tr>
                <td>${r.rentalId}</td>
                <td>${fmt(r.customerName)}</td>
                <td>${fmt(r.vehicleInfo)}</td>
                <td>${fmt(r.licensePlate || '—')}</td>
                <td>${fmt(r.pickupLocationName)}</td>
                <td>${fmtDate(r.actualPickup)}</td>
                <td>${fmt(r.odometerOut)}</td>
                <td>${fmtMoney(r.baseCharge)}</td>
                <td>${statusBadge(r.status)}</td>
            </tr>`;
        });
    } catch (e) {
        showToast('Rentals load error: ' + e.message, 'error');
    }
}

// ============================================================
// BEGIN RENTAL
// ============================================================
async function beginRental() {
    const resultEl = document.getElementById('rentalResult');
    const payload = {
        action:        'begin',
        reservationId: document.getElementById('nr_reservationId').value,
        employeeId:    document.getElementById('nr_employeeId').value,
        odometerOut:   document.getElementById('nr_odometerOut').value
    };
    if (!payload.reservationId || !payload.employeeId || !payload.odometerOut) {
        resultEl.textContent = '⚠ Please fill all required fields.';
        resultEl.className = 'result-area error';
        resultEl.classList.remove('hidden');
        return;
    }
    try {
        const res = await apiFetch(`${BASE_URL}/rentals`, {
            method: 'POST',
            body: JSON.stringify(payload)
        });
        resultEl.textContent = `✅ Rental started successfully! Rental ID: ${res.rentalId}`;
        resultEl.className = 'result-area';
        resultEl.classList.remove('hidden');
        showToast('Rental #' + res.rentalId + ' started', 'success');
    } catch (e) {
        resultEl.textContent = '❌ Error: ' + e.message;
        resultEl.className = 'result-area error';
        resultEl.classList.remove('hidden');
    }
}

// ============================================================
// COMPLETE RENTAL
// ============================================================
async function completeRental() {
    const resultEl = document.getElementById('returnResult');
    const payload = {
        rentalId:    document.getElementById('ret_rentalId').value,
        employeeId:  document.getElementById('ret_employeeId').value,
        odometerIn:  document.getElementById('ret_odometerIn').value,
        fuelLevelIn: document.getElementById('ret_fuelLevel').value,
        damageNotes: document.getElementById('ret_damageNotes').value
    };
    if (!payload.rentalId || !payload.employeeId || !payload.odometerIn) {
        resultEl.textContent = '⚠ Please fill all required fields.';
        resultEl.className = 'result-area error';
        resultEl.classList.remove('hidden');
        return;
    }
    try {
        const res = await apiFetch(`${BASE_URL}/rentals`, {
            method: 'PUT',
            body: JSON.stringify(payload)
        });
        resultEl.textContent = '✅ ' + res.message;
        resultEl.className = 'result-area';
        resultEl.classList.remove('hidden');
        showToast('Rental completed successfully', 'success');
    } catch (e) {
        resultEl.textContent = '❌ Error: ' + e.message;
        resultEl.className = 'result-area error';
        resultEl.classList.remove('hidden');
    }
}

// ============================================================
// REPORTS
// ============================================================
function initReportDates() {
    const now  = new Date();
    const from = new Date(now.getFullYear(), now.getMonth() - 5, 1);
    document.getElementById('reportFrom').value = from.toISOString().substring(0,10);
    document.getElementById('reportTo').value   = now.toISOString().substring(0,10);
    loadReport();
}

async function loadReport() {
    const from = document.getElementById('reportFrom').value;
    const to   = document.getElementById('reportTo').value;
    try {
        const data = await apiFetch(`${BASE_URL}/rentals?action=report&from=${from}&to=${to}`);
        const tbody = document.getElementById('reportBody');
        tbody.innerHTML = '';
        (data.rows || []).forEach(row => {
            const isTotals = String(row[0]) === 'TOTAL';
            const cls = isTotals ? 'style="font-weight:700;background:#f8f9fa;"' : '';
            tbody.innerHTML += `<tr ${cls}>
                <td>${row[0]}</td>
                <td>${fmt(row[1])}</td>
                <td>${fmtMoney(row[2])}</td>
                <td>${fmtMoney(row[3])}</td>
                <td>${fmtMoney(row[4])}</td>
                <td>${fmtMoney(row[5])}</td>
                <td>${fmtMoney(row[6])}</td>
                <td>${fmtMoney(row[7])}</td>
            </tr>`;
        });
    } catch (e) {
        showToast('Report error: ' + e.message, 'error');
    }
}

// ============================================================
// OVERDUE
// ============================================================
async function loadOverdue() {
    try {
        const data = await apiFetch(`${BASE_URL}/rentals?action=overdue`);
        const tbody = document.getElementById('overdueBody');
        tbody.innerHTML = '';
        (data.data || []).forEach(r => {
            tbody.innerHTML += `<tr style="background:#fff5f5">
                <td>${r.rentalId}</td>
                <td>${fmt(r.customerName)}</td>
                <td>${fmt(r.vehicleInfo)}</td>
                <td>${fmt(r.pickupLocationName)}</td>
                <td>${fmtDate(r.actualPickup)}</td>
                <td>${statusBadge(r.status)}</td>
            </tr>`;
        });
        if ((data.data || []).length === 0) {
            tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;padding:20px;color:#6c757d;">No overdue rentals 🎉</td></tr>';
        }
    } catch (e) {
        showToast('Overdue load error: ' + e.message, 'error');
    }
}

// ============================================================
// MODALS
// ============================================================
function openModal(id) {
    document.getElementById(id).classList.add('open');
}
function closeModal(id) {
    document.getElementById(id).classList.remove('open');
}
// Close modal on backdrop click
document.querySelectorAll('.modal-backdrop').forEach(bd => {
    bd.addEventListener('click', e => {
        if (e.target === bd) bd.classList.remove('open');
    });
});

// ============================================================
// TOAST NOTIFICATIONS
// ============================================================
function showToast(msg, type = '') {
    const t = document.getElementById('toast');
    t.textContent = msg;
    t.className   = 'toast' + (type ? ' ' + type : '');
    t.classList.remove('hidden');
    clearTimeout(window._toastTimer);
    window._toastTimer = setTimeout(() => t.classList.add('hidden'), 3500);
}

// ============================================================
// INIT on page load
// ============================================================
window.addEventListener('DOMContentLoaded', () => {
    loadDashboard();
});
