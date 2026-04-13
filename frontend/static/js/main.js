/* ============================================================
   main.js — Ticket Booking System
   Handles: API calls, auth state, toast, modal, shared utils
   ============================================================ */

const API = 'http://127.0.0.1:5000/api';

/* ── Auth State ─────────────────────────────────────────────── */
const Auth = {
  get() {
    try { return JSON.parse(localStorage.getItem('tbs_user') || 'null'); } catch { return null; }
  },
  set(user) {
    localStorage.setItem('tbs_user', JSON.stringify(user));
  },
  clear() {
    localStorage.removeItem('tbs_user');
  },
  isLoggedIn() {
    return !!this.get();
  },
  isRole(role) {
    const u = this.get();
    return u && u.role === role;
  }
};

/* ── API Helper ─────────────────────────────────────────────── */
async function apiFetch(path, options = {}) {
  const res = await fetch(API + path, {
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    ...options
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Something went wrong');
  return data;
}

/* ── Toast ──────────────────────────────────────────────────── */
function showToast(msg, type = 'info') {
  let container = document.getElementById('toast-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'toast-container';
    container.className = 'toast-container';
    document.body.appendChild(container);
  }
  const icons = { success: '✓', error: '✕', info: 'ℹ' };
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.innerHTML = `<span class="toast-icon">${icons[type] || icons.info}</span><span class="toast-msg">${msg}</span>`;
  container.appendChild(toast);
  setTimeout(() => { toast.style.opacity = '0'; toast.style.transform = 'translateX(100%)'; toast.style.transition = '0.3s'; setTimeout(() => toast.remove(), 300); }, 3000);
}

/* ── Modal helpers ──────────────────────────────────────────── */
function openModal(id) {
  const el = document.getElementById(id);
  if (el) el.classList.add('open');
}
function closeModal(id) {
  const el = document.getElementById(id);
  if (el) el.classList.remove('open');
}

/* ── Navbar renderer ────────────────────────────────────────── */
function renderNavbar(activePage = '') {
  const user = Auth.get();
  const navEl = document.getElementById('navbar');
  if (!navEl) return;

  const links = [
    { href: 'events.html',       label: 'Browse Events' },
    { href: 'sql-explorer.html', label: '🗄️ SQL Explorer' },
  ];
  if (user) {
    links.push({ href: 'dashboard.html', label: 'My Bookings' });
    if (user.role === 'admin') links.push({ href: 'admin.html', label: 'Admin' });
  }

  navEl.innerHTML = `
    <div class="container">
      <a href="dashboard.html" class="nav-brand">🎟 Book<span>My</span>Show</a>
      <nav class="nav-links">
        ${links.map(l => `<a href="${l.href}" class="${activePage === l.href ? 'active' : ''}">${l.label}</a>`).join('')}
      </nav>
      <div class="nav-actions">
        ${user ? `
          <div class="nav-user">
            <span>Hi, <strong>${user.full_name.split(' ')[0]}</strong></span>
            <span class="role-badge">${user.role}</span>
          </div>
          <button class="btn btn-ghost btn-sm" onclick="handleLogout()">Logout</button>
        ` : `
          <a href="login.html" class="btn btn-ghost btn-sm">Login</a>
          <a href="register.html" class="btn btn-gold btn-sm">Sign Up</a>
        `}
      </div>
    </div>
  `;
}

async function handleLogout() {
  try {
    await apiFetch('/auth/logout', { method: 'POST' });
  } catch (_) {}
  Auth.clear();
  showToast('Logged out successfully', 'info');
  setTimeout(() => window.location.href = 'login.html', 800);
}

/* ── Require login guard ────────────────────────────────────── */
function requireLogin(redirectTo = 'login.html') {
  if (!Auth.isLoggedIn()) {
    window.location.href = redirectTo;
    return false;
  }
  return true;
}

/* ── Status pill ────────────────────────────────────────────── */
function statusPill(status) {
  return `<span class="status-pill status-${status}">${status}</span>`;
}

/* ── Star renderer ──────────────────────────────────────────── */
function renderStars(rating, max = 5) {
  let html = '<div class="stars">';
  for (let i = 1; i <= max; i++) {
    html += `<span class="${i <= rating ? '' : 'star-empty'}">★</span>`;
  }
  return html + '</div>';
}

/* ── Format date ────────────────────────────────────────────── */
function fmtDate(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
}

function fmtDateShort(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
}

/* ── Format currency ────────────────────────────────────────── */
function fmtCurrency(n) {
  if (n === null || n === undefined) return '—';
  return '₹' + Number(n).toLocaleString('en-IN', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
}

/* ── Category emoji ─────────────────────────────────────────── */
function categoryEmoji(cat) {
  const map = { Music: '🎵', Sports: '⚽', Comedy: '😄', Theatre: '🎭', Dance: '💃', Food: '🍽', Art: '🎨', Tech: '💻', Festival: '🎪', Other: '🎪' };
  return map[cat] || '🎟';
}

/* ── Close modals on overlay click ─────────────────────────── */
document.addEventListener('click', (e) => {
  if (e.target.classList.contains('modal-overlay')) {
    e.target.classList.remove('open');
  }
});
