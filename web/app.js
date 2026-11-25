const API = (window.SILAH_CONFIG?.apiBaseUrl || 'https://backend-finytive.vercel.app/v1').replace(/\/$/, '');
const TOKEN_KEY = 'silah_super_admin_access';
const REFRESH_KEY = 'silah_super_admin_refresh';
const app = document.querySelector('#app');
const toastRoot = document.querySelector('#toast-root');

const state = {
  token: sessionStorage.getItem(TOKEN_KEY),
  refreshToken: sessionStorage.getItem(REFRESH_KEY),
  user: null,
  view: 'overview',
  loading: false,
  page: 1,
  hasMore: false,
  rows: [],
  filters: { search: '', status: 'ALL', approvalStatus: 'ALL', sort: 'CREATED_DESC', createdFrom: '', createdTo: '' },
  userSearch: '',
  broadcasts: [],
};

const escapeHtml = (value = '') => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const unwrap = body => body && Object.prototype.hasOwnProperty.call(body, 'data') ? body.data : body;
const money = value => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(Number(value) || 0);
const dateLabel = value => value ? new Intl.DateTimeFormat('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }).format(new Date(value)) : '—';
const initials = name => (String(name || 'SA').trim().split(/\s+/).slice(0, 2).map(s => s[0]).join('') || 'SA').toUpperCase();

async function api(path, options = {}, retried = false) {
  const headers = { Accept: 'application/json', ...(options.body ? { 'Content-Type': 'application/json' } : {}), ...(options.headers || {}) };
  if (options.auth !== false && state.token) headers.Authorization = `Bearer ${state.token}`;
  const response = await fetch(`${API}${path}`, { method: options.method || 'GET', headers, body: options.body ? JSON.stringify(options.body) : undefined });
  let body;
  try { body = await response.json(); } catch { body = null; }
  if (response.status === 401 && !retried && state.refreshToken && !path.includes('/auth/')) {
    const refreshed = await refreshSession();
    if (refreshed) return api(path, options, true);
  }
  if (!response.ok || body?.success === false) {
    const error = body?.error;
    const message = Array.isArray(error?.message) ? error.message.join(', ') : error?.message || body?.message || `Request failed (${response.status})`;
    if (response.status === 401) signOut(false);
    throw new Error(message);
  }
  return unwrap(body);
}

async function refreshSession() {
  try {
    const data = await api('/auth/refresh', { method: 'POST', auth: false, body: { refreshToken: state.refreshToken } }, true);
    const tokens = data?.tokens || data;
    state.token = tokens?.accessToken;
    state.refreshToken = tokens?.refreshToken || state.refreshToken;
    sessionStorage.setItem(TOKEN_KEY, state.token || '');
    sessionStorage.setItem(REFRESH_KEY, state.refreshToken || '');
    return Boolean(state.token);
  } catch { signOut(false); return false; }
}

function toast(message, error = false) {
  toastRoot.innerHTML = `<div class="toast ${error ? 'error' : ''}">${escapeHtml(message)}</div>`;
  window.setTimeout(() => { toastRoot.innerHTML = ''; }, 3600);
}

function signOut(showMessage = true) {
  state.token = null; state.refreshToken = null; state.user = null;
  sessionStorage.removeItem(TOKEN_KEY); sessionStorage.removeItem(REFRESH_KEY);
  if (showMessage) toast('Signed out.');
  renderLogin();
}

function renderLogin(error = '', otpSent = false, phone = '') {
  app.innerHTML = `<main class="login-wrap">
    <section class="login-story">
      <div><div class="brand"><span class="brand-mark">S</span><div><div class="brand-title">Silah</div><div class="brand-sub">SUPER ADMIN PORTAL</div></div></div>
        <div><div class="eyebrow gold">Community operations</div><h1>One place to care for every <span class="gold">masjid.</span></h1><p>Review requests, keep the directory current, support members, and share important updates across Silah.</p></div>
      </div><div class="login-foot">Secure access for authorized Super Administrators</div>
    </section>
    <section class="login-card-wrap"><div class="login-card">
      <div class="brand-mark" style="margin-bottom:20px">S</div>
      <h2>${otpSent ? 'Check your phone' : 'Welcome back'}</h2>
      <p>${otpSent ? `Enter the six-digit code sent to ${escapeHtml(phone)}.` : 'Sign in with the Super Admin mobile number registered in Silah.'}</p>
      ${error ? `<div class="form-error" role="alert">${escapeHtml(error)}</div>` : ''}
      ${otpSent ? `<form id="otp-form"><input type="hidden" name="phone" value="${escapeHtml(phone)}"><div class="field"><label for="otp">One-time code</label><input id="otp" name="otp" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6}" maxlength="6" placeholder="••••••" required autofocus></div><button class="btn btn-primary btn-block" type="submit">Verify and continue <span>→</span></button><button class="btn btn-outline btn-block" style="margin-top:9px" type="button" data-action="back-login" data-phone="${escapeHtml(phone)}">Use another number</button></form>` :
        `<form id="phone-form"><div class="field"><label for="phone">Mobile number</label><input id="phone" name="phone" autocomplete="tel" inputmode="tel" placeholder="10-digit mobile number" value="${escapeHtml(phone)}" required><small>Use the same number assigned Super Admin access.</small></div><button class="btn btn-primary btn-block" type="submit">Send sign-in code <span>→</span></button></form>`}
      <p style="font-size:10px;margin:18px 0 0">Your access is checked against the Silah backend account.</p>
    </div></section>
  </main>`;
}

async function initialize() {
  if (!state.token) return renderLogin();
  try {
    const data = await api('/auth/me');
    state.user = data?.user || data;
    if (!state.user?.isSuperAdmin) throw new Error('This account does not have Super Admin access.');
    await loadView('overview');
  } catch (error) {
    if (state.token) signOut(false);
    renderLogin(error.message);
  }
}

function shell(title, body) {
  const nav = [
    ['overview', '▦', 'Overview'], ['requests', '◷', 'Masjid requests'],
    ['masjids', '⌂', 'Masjid directory'], ['users', '♙', 'Users'],
    ['broadcasts', '◉', 'Broadcasts'],
  ];
  app.innerHTML = `<div class="shell">
    <aside class="sidebar" id="sidebar">
      <div class="brand"><span class="brand-mark">S</span><div><div class="brand-title">Silah</div><div class="brand-sub">SUPER ADMIN</div></div></div>
      <div class="nav-label">Workspace</div><nav class="nav-list">${nav.map(([key, icon, label]) => `<button class="nav-item ${state.view === key ? 'active' : ''}" data-view="${key}"><span class="nav-icon">${icon}</span>${label}${key === 'requests' ? `<span class="pill pending" data-pending-count style="margin-left:auto;${state.pendingCount ? '' : 'display:none'}">${state.pendingCount || ''}</span>` : ''}</button>`).join('')}</nav>
      <div class="sidebar-spacer"></div>
      <div class="side-user"><span class="avatar">${escapeHtml(initials(state.user?.name))}</span><div><div class="side-user-name">${escapeHtml(state.user?.name || 'Super Admin')}</div><div class="side-user-role">Super Administrator</div></div><button class="logout" title="Sign out" data-action="logout">↗</button></div>
    </aside>
    <section class="main">
      <header class="topbar"><div style="display:flex;align-items:center;gap:12px"><button class="mobile-menu" data-action="menu" aria-label="Open menu">☰</button><div class="top-title">${escapeHtml(title)}</div></div><div class="top-meta"><span><i class="connection-dot"></i>Live Silah data</span><span>${new Intl.DateTimeFormat('en-IN',{weekday:'short',day:'numeric',month:'short'}).format(new Date())}</span></div></header>
      <main class="content" id="content">${body}</main>
      <nav class="mobile-nav"><div class="mobile-nav-inner">${nav.map(([key, icon, label]) => `<button class="${state.view === key ? 'active' : ''}" data-view="${key}"><span>${icon}</span>${label}</button>`).join('')}</div></nav>
    </section>
  </div>`;
}

function pageHead(kicker, title, description, actions = '') {
  return `<div class="page-head"><div><div class="eyebrow">${escapeHtml(kicker)}</div><h1>${escapeHtml(title)}</h1><p>${escapeHtml(description)}</p></div>${actions ? `<div class="head-actions">${actions}</div>` : ''}</div>`;
}
function metric(label, value, icon, note = '') {
  return `<article class="metric"><div class="metric-top"><span>${escapeHtml(label)}</span><span class="metric-icon">${icon}</span></div><div class="metric-value">${escapeHtml(value)}</div><div class="metric-note">${escapeHtml(note)}</div></article>`;
}
function loading(label = 'Loading live data…') { return `<div class="loading"><div class="spinner"></div>${escapeHtml(label)}</div>`; }
function empty(icon, title, detail = '') { return `<div class="empty"><div class="empty-icon">${icon}</div><strong>${escapeHtml(title)}</strong>${detail ? `<div style="font-size:11px;margin-top:6px">${escapeHtml(detail)}</div>` : ''}</div>`; }
function statusPill(status, active = null) {
  const val = active === false ? 'Inactive' : String(status || (active === true ? 'Active' : 'Unknown')).replaceAll('_', ' ');
  const cls = active === false || val === 'REJECTED' ? 'rejected' : val === 'PENDING' ? 'pending' : active === true || val === 'APPROVED' || val === 'Active' ? 'success' : 'off';
  return `<span class="pill ${cls}">${cls === 'success' ? '✓' : cls === 'pending' ? '◷' : cls === 'rejected' ? '×' : '•'} ${escapeHtml(val)}</span>`;
}

async function loadView(view, options = {}) {
  state.view = view;
  state.loading = true;
  if (options.reset !== false) { state.page = 1; state.rows = []; state.hasMore = false; }
  const titles = { overview: 'Overview', requests: 'Masjid requests', masjids: 'Masjid directory', users: 'Users', broadcasts: 'Broadcasts' };
  shell(titles[view], loading());
  try {
    if (view === 'overview') await renderOverview();
    if (view === 'requests') await renderRequests();
    if (view === 'masjids') await renderMasjids(options);
    if (view === 'users') await renderUsers(options);
    if (view === 'broadcasts') await renderBroadcasts();
  } catch (error) {
    document.querySelector('#content').innerHTML = `${pageHead('Could not load', titles[view] || 'Silah', 'The backend request failed.')}<div class="form-error">${escapeHtml(error.message)}</div><button class="btn btn-primary" data-action="refresh">Try again</button>`;
  } finally { state.loading = false; }
}

async function renderOverview() {
  const data = await api('/dashboard/super-admin');
  const metrics = data?.metrics || {};
  const requests = data?.pendingRequests || [];
  state.pendingCount = metrics.pendingRequestsCount || 0;
  const recent = data?.recentMasjids || [];
  const html = `${pageHead('System health', 'Good morning, admin', 'Here is the latest activity across the Silah community.', `<button class="btn btn-outline" data-action="refresh">↻ Refresh</button><button class="btn btn-primary" data-action="create-masjid">＋ New masjid</button>`)}
    <section class="metrics">
      ${metric('Active masjids', Number(metrics.totalMasjids || 0).toLocaleString('en-IN'), '⌂', 'Approved and active')}
      ${metric('Registered users', Number(metrics.totalUsers || 0).toLocaleString('en-IN'), '♙', 'Accounts in Silah')}
      ${metric('Active in 30 days', Number(metrics.activeUsersLast30Days || 0).toLocaleString('en-IN'), '↗', 'Users with an active device')}
      ${metric('Needs review', Number(metrics.pendingRequestsCount || 0).toLocaleString('en-IN'), '◷', 'Masjid requests awaiting action')}
    </section>
    <section class="metrics">
      ${metric('Sandha due / month', money(metrics.monthlySandhaExpected), '₹', 'Estimated from active plans')}
      ${metric('Collected this month', money(metrics.currentMonthSandhaCollected), '↗', 'Recorded paid and partial')}
      ${metric('All-time collections', money(metrics.totalSandhaCollected), '₹', `${Number(metrics.totalTransactions || 0).toLocaleString('en-IN')} recorded payments`)}
      ${metric('Following a masjid', Number(metrics.totalFollowers || 0).toLocaleString('en-IN'), '♡', 'Member-to-masjid links')}
    </section>
    <section class="split"><article class="panel"><div class="panel-head"><div class="panel-title">Recent masjids</div><button class="btn btn-soft btn-sm" data-view="masjids">Open directory →</button></div><div class="table-wrap"><table><thead><tr><th>Masjid</th><th>City</th><th>Members</th><th>Status</th><th>Added</th></tr></thead><tbody>${recent.length ? recent.map(m => `<tr><td><div class="primary-cell">${escapeHtml(m.name)}</div><div class="secondary-cell">${escapeHtml(m.address || '')}</div></td><td>${escapeHtml(m.city || '—')}</td><td>${Number(m._count?.memberships || 0)}</td><td>${statusPill(m.approvalStatus, m.isActive)}</td><td>${dateLabel(m.createdAt)}</td></tr>`).join('') : `<tr><td colspan="5">${empty('⌂','No masjids found')}</td></tr>`}</tbody></table></div></article>
      <article class="panel"><div class="panel-head"><div class="panel-title">Requests to review</div><button class="btn btn-soft btn-sm" data-view="requests">View all →</button></div><div class="panel-body">${requests.length ? `<div class="request-list">${requests.slice(0,4).map(requestCard).join('')}</div>` : empty('✓','All caught up','No pending masjid requests.')}</div></article></section>`;
  document.querySelector('#content').innerHTML = html;
  updateNavBadges();
}

function requestCard(item) {
  return `<div class="request-card"><div><h3>${escapeHtml(item.name)}</h3><p>${escapeHtml(item.city || '')} · ${escapeHtml(item.creator?.name || 'Applicant')}<br>${escapeHtml(item.creator?.phone || '')} · ${dateLabel(item.createdAt)}</p></div><div class="request-actions"><button class="btn btn-soft btn-sm" data-action="approve-request" data-id="${escapeHtml(item.id)}">Approve</button><button class="btn btn-danger btn-sm" data-action="reject-request" data-id="${escapeHtml(item.id)}">Reject</button></div></div>`;
}

async function renderRequests() {
  const requests = await api('/masjids/requests/pending');
  state.pendingCount = requests.length;
  updateNavBadges();
  document.querySelector('#content').innerHTML = `${pageHead('Approvals', 'Masjid requests', 'Review new masjid registrations before they appear to members.')}
    <section class="panel"><div class="panel-head"><div class="panel-title">Waiting for your decision</div><span class="pill pending">${requests.length} pending</span></div><div class="panel-body">${requests.length ? `<div class="request-list">${requests.map(requestCard).join('')}</div>` : empty('✓','No requests waiting','New submissions will appear here when they arrive.')}</div></section>`;
}

function masjidQuery(page = 1) {
  const f = state.filters; const q = new URLSearchParams({ page: String(page), limit: '20', sort: f.sort });
  if (f.search) q.set('search', f.search);
  if (f.status !== 'ALL') q.set('status', f.status);
  if (f.approvalStatus !== 'ALL') q.set('approvalStatus', f.approvalStatus);
  if (f.createdFrom) q.set('createdFrom', f.createdFrom);
  if (f.createdTo) q.set('createdTo', f.createdTo);
  return q.toString();
}

async function renderMasjids(options = {}) {
  const result = await api(`/masjids/admin/directory?${masjidQuery(state.page)}`);
  const items = result?.items || [];
  state.rows = options.append ? [...state.rows, ...items] : items;
  state.hasMore = Boolean(state.page * (result?.limit || 20) < (result?.total || 0));
  document.querySelector('#content').innerHTML = `${pageHead('Directory', 'Masjid directory', `${Number(result?.total || 0).toLocaleString('en-IN')} records in the database.`, `<button class="btn btn-primary" data-action="create-masjid">＋ New masjid</button>`)}
    <section class="panel"><div class="panel-head"><div class="panel-title">All masjids</div><span class="pill">Batch of 20</span></div><div class="panel-body"><form class="toolbar" id="masjid-filters">
      <input class="search" name="search" type="search" placeholder="Search name, city, address…" value="${escapeHtml(state.filters.search)}">
      <select name="status"><option value="ALL">All activity</option><option value="ACTIVE" ${state.filters.status==='ACTIVE'?'selected':''}>Active</option><option value="STOPPED" ${state.filters.status==='STOPPED'?'selected':''}>Stopped</option></select>
      <select name="approvalStatus"><option value="ALL">All approvals</option><option value="APPROVED" ${state.filters.approvalStatus==='APPROVED'?'selected':''}>Approved</option><option value="PENDING" ${state.filters.approvalStatus==='PENDING'?'selected':''}>Pending</option><option value="REJECTED" ${state.filters.approvalStatus==='REJECTED'?'selected':''}>Rejected</option></select>
      <select name="sort"><option value="CREATED_DESC" ${state.filters.sort==='CREATED_DESC'?'selected':''}>Newest first</option><option value="CREATED_ASC" ${state.filters.sort==='CREATED_ASC'?'selected':''}>Oldest first</option><option value="NAME_ASC" ${state.filters.sort==='NAME_ASC'?'selected':''}>Name A–Z</option><option value="NAME_DESC" ${state.filters.sort==='NAME_DESC'?'selected':''}>Name Z–A</option></select>
      <label>From <input name="createdFrom" type="date" value="${escapeHtml(state.filters.createdFrom)}" aria-label="Created from"></label><label>To <input name="createdTo" type="date" value="${escapeHtml(state.filters.createdTo)}" aria-label="Created to"></label>
      <button class="btn btn-primary btn-sm" type="submit">Apply</button><button class="btn btn-outline btn-sm" type="button" data-action="clear-masjid-filters">Reset</button>
    </form></div><div class="table-wrap" id="masjid-list"><table><thead><tr><th>Masjid</th><th>Contact</th><th>Approval</th><th>Activity</th><th>Members</th><th>Added</th><th></th></tr></thead><tbody>${state.rows.length ? state.rows.map(m => `<tr><td><button class="primary-cell link-button" data-action="masjid-detail" data-id="${escapeHtml(m.id)}">${escapeHtml(m.name)}</button><div class="secondary-cell">${escapeHtml(m.city || '')} · ${escapeHtml(m.address || '')}</div></td><td>${escapeHtml(m.phone || '—')}</td><td>${statusPill(m.approvalStatus)}</td><td>${statusPill(null, m.isActive)}</td><td>${Number(m._count?.memberships || 0)}</td><td>${dateLabel(m.createdAt)}</td><td><div class="cell-actions"><button class="btn btn-outline btn-sm" data-action="toggle-masjid" data-id="${escapeHtml(m.id)}" data-active="${Boolean(m.isActive)}">${m.isActive ? 'Stop' : 'Activate'}</button><button class="btn btn-danger btn-sm" data-action="delete-masjid" data-id="${escapeHtml(m.id)}">Delete</button></div></td></tr>`).join('') : `<tr><td colspan="7">${empty('⌂','No matching masjids','Try changing the search or filters.')}</td></tr>`}</tbody></table>${state.hasMore ? `<div class="pagination-note" data-more="masjids">Scroll for more masjids</div>` : `<div class="pagination-note">End of directory · ${state.rows.length} shown</div>`}</div></section>`;
}

async function renderUsers(options = {}) {
  const q = new URLSearchParams({ page: String(state.page), limit: '20' });
  if (state.userSearch) q.set('search', state.userSearch);
  const result = await api(`/users?${q}`); const data = result || {};
  const items = data.items || [];
  state.rows = options.append ? [...state.rows, ...items] : items;
  state.hasMore = Boolean(state.page * (data.limit || 20) < (data.total || 0));
  document.querySelector('#content').innerHTML = `${pageHead('People', 'User management', `${Number(data.total || 0).toLocaleString('en-IN')} registered accounts.`, `<button class="btn btn-primary" data-action="create-user">＋ Add user</button>`)}
    <section class="panel"><div class="panel-head"><div class="panel-title">All accounts</div><span class="pill">Batch of 20</span></div><div class="panel-body"><form class="toolbar" id="user-search"><input class="search" name="search" type="search" value="${escapeHtml(state.userSearch)}" placeholder="Search name or phone number"><button class="btn btn-primary btn-sm">Search</button></form></div><div class="table-wrap" id="user-list"><table><thead><tr><th>User</th><th>Phone</th><th>Type</th><th>Account</th><th>Joined</th><th></th></tr></thead><tbody>${state.rows.length ? state.rows.map(u => `<tr><td><div class="primary-cell">${escapeHtml(u.name)}</div><div class="secondary-cell">${escapeHtml(u.address || '')}</div></td><td>${escapeHtml(u.phone)}</td><td>${u.isSuperAdmin ? '<span class="pill success">Super Admin</span>' : 'Member'}</td><td>${statusPill(null, u.isActive)}</td><td>${dateLabel(u.createdAt)}</td><td><div class="cell-actions"><button class="btn btn-outline btn-sm" data-action="toggle-user" data-id="${escapeHtml(u.id)}" data-active="${Boolean(u.isActive)}">${u.isActive ? 'Deactivate' : 'Activate'}</button><button class="btn btn-danger btn-sm" data-action="delete-user" data-id="${escapeHtml(u.id)}">Delete</button></div></td></tr>`).join('') : `<tr><td colspan="6">${empty('♙','No users found')}</td></tr>`}</tbody></table>${state.hasMore ? `<div class="pagination-note" data-more="users">Scroll for more users</div>` : `<div class="pagination-note">End of list · ${state.rows.length} shown</div>`}</div></section>`;
}

async function renderBroadcasts() {
  const list = await api('/announcements/broadcasts/admin'); state.broadcasts = Array.isArray(list) ? list : [];
  document.querySelector('#content').innerHTML = `${pageHead('Communication', 'Broadcasts', 'Send a notice to the selected Silah audience. Recipients receive an in-app notice and push when registered.')}
    <section class="split"><article class="panel"><div class="panel-head"><div class="panel-title">Create a broadcast</div><span class="pill">Backend delivery</span></div><div class="panel-body"><form id="broadcast-form"><div class="field"><label>Heading</label><input name="title" maxlength="200" required placeholder="A clear notice heading"></div><div class="field"><label>Message</label><textarea name="body" required placeholder="Write the notice message"></textarea></div><div class="field"><label>Audience</label><select name="targetAudience"><option value="ALL">All users</option><option value="ADMINS">Masjid admins</option><option value="MUSALLIS">Members</option></select></div><button class="btn btn-primary" type="submit">Send broadcast <span>→</span></button></form></div></article>
      <article class="panel"><div class="panel-head"><div class="panel-title">Delivery notes</div></div><div class="panel-body" style="font-size:12px;line-height:1.7;color:var(--muted)"><p>Broadcast content is saved by the Silah backend before push delivery.</p><p>Push delivery depends on each recipient having an active registered device token and permission to receive notifications.</p><p>Read counts come from saved notice state.</p></div></article></section>
    <section class="panel" style="margin-top:16px"><div class="panel-head"><div class="panel-title">Recent broadcasts</div><span class="pill">${state.broadcasts.length} records</span></div><div class="table-wrap"><table><thead><tr><th>Heading</th><th>Message</th><th>Read</th><th>Created</th><th></th></tr></thead><tbody>${state.broadcasts.length ? state.broadcasts.map(n => `<tr><td><div class="primary-cell">${escapeHtml(n.title)}</div><div class="secondary-cell">${escapeHtml(n.creator?.name || '')}</div></td><td style="max-width:380px">${escapeHtml(n.body)}</td><td>${Number(n.readCount || 0)}</td><td>${dateLabel(n.createdAt || n.publishedAt)}</td><td><button class="btn btn-danger btn-sm" data-action="delete-broadcast" data-id="${escapeHtml(n.id)}">Delete</button></td></tr>`).join('') : `<tr><td colspan="5">${empty('◉','No broadcasts yet')}</td></tr>`}</tbody></table></div></section>`;
}

function updateNavBadges() {
  const badge = document.querySelector('[data-pending-count]');
  if (!badge) return;
  badge.textContent = state.pendingCount ? String(state.pendingCount) : '';
  badge.style.display = state.pendingCount ? '' : 'none';
}

function showModal(title, body, footer = '') {
  document.body.insertAdjacentHTML('beforeend', `<div class="modal-backdrop" id="modal-backdrop"><section class="modal" role="dialog" aria-modal="true"><header class="modal-head"><h2>${escapeHtml(title)}</h2><button class="modal-close" data-action="close-modal" aria-label="Close">×</button></header><div class="modal-body">${body}</div>${footer ? `<footer class="modal-foot">${footer}</footer>` : ''}</section></div>`);
}
function closeModal() { document.querySelector('#modal-backdrop')?.remove(); }

function showMasjidForm() {
  showModal('Create a masjid', `<form id="masjid-create-form"><div class="grid-2"><div class="field"><label>Masjid name *</label><input name="name" required maxlength="200"></div><div class="field"><label>City *</label><input name="city" required maxlength="100"></div></div><div class="field"><label>Address *</label><input name="address" required></div><div class="grid-2"><div class="field"><label>State</label><input name="state"></div><div class="field"><label>Phone</label><input name="phone" type="tel"></div></div><div class="field"><label>Map link</label><input name="mapUrl" type="url" placeholder="https://maps.app.goo.gl/…"></div><div class="field"><label>Admin phone (optional)</label><input name="adminPhone" type="tel"><small>If supplied, the existing user is mapped as this masjid's admin.</small></div><div class="field"><label>Admin name (optional)</label><input name="adminName"></div></form>`, `<button class="btn btn-outline" data-action="close-modal">Cancel</button><button class="btn btn-primary" form="masjid-create-form">Create masjid</button>`);
}
function showUserForm() {
  showModal('Add a user', `<form id="user-create-form"><div class="field"><label>Full name *</label><input name="name" required maxlength="100"></div><div class="field"><label>Mobile number *</label><input name="phone" type="tel" required placeholder="+919876543210"></div><div class="field"><label>Address</label><input name="address"></div><label style="display:flex;align-items:center;gap:9px;font-size:12px;margin-bottom:12px"><input type="checkbox" name="isSuperAdmin"> Grant Super Admin access</label><div class="form-error" style="margin:0">Only grant Super Admin access to trusted operators.</div></form>`, `<button class="btn btn-outline" data-action="close-modal">Cancel</button><button class="btn btn-primary" form="user-create-form">Create account</button>`);
}

function showDetail(label, value) { return `<div class="detail-item"><div class="detail-label">${escapeHtml(label)}</div><div class="detail-value">${escapeHtml(value || '—')}</div></div>`; }
async function showMasjidDetail(id) {
  showModal('Masjid details', loading('Loading masjid details…'));
  try {
    const m = await api(`/masjids/${encodeURIComponent(id)}`);
    const data = m?.masjid || m;
    document.querySelector('#modal-backdrop .modal-body').innerHTML = `<div class="detail-grid">${showDetail('Name', data.name)}${showDetail('Approval', data.approvalStatus)}${showDetail('Activity', data.isActive ? 'Active' : 'Inactive')}${showDetail('City', data.city)}${showDetail('Address', data.address)}${showDetail('Phone', data.phone)}${showDetail('Created by', data.creator?.name)}${showDetail('Created', dateLabel(data.createdAt))}${showDetail('Members', data._count?.memberships)}${showDetail('Assigned admins', data._count?.admins)}${showDetail('Map link', data.mapUrl)}</div>`;
  } catch (error) { document.querySelector('#modal-backdrop .modal-body').innerHTML = `<div class="form-error">${escapeHtml(error.message)}</div>`; }
}

async function approveRequest(id) {
  if (!confirm('Approve this masjid request? The masjid will become active and the applicant will receive admin access.')) return;
  await api(`/masjids/requests/${encodeURIComponent(id)}/approve`, { method: 'POST' });
  toast('Masjid request approved.'); await loadView(state.view);
}
async function rejectRequest(id) {
  const reason = prompt('Optional reason for rejecting this request:');
  if (reason === null) return;
  await api(`/masjids/requests/${encodeURIComponent(id)}/reject`, { method: 'POST', body: reason.trim() ? { reason: reason.trim() } : {} });
  toast('Masjid request rejected.'); await loadView(state.view);
}

async function loadMore() {
  if (state.loading || !state.hasMore || !['masjids', 'users'].includes(state.view)) return;
  const priorScroll = document.querySelector('.table-wrap')?.scrollTop || 0;
  state.loading = true; state.page += 1;
  const note = document.querySelector('[data-more]'); if (note) note.textContent = 'Loading next 20…';
  try {
    await (state.view === 'masjids' ? renderMasjids({ append: true }) : renderUsers({ append: true }));
    const nextWrap = document.querySelector('.table-wrap');
    if (nextWrap) nextWrap.scrollTop = priorScroll;
  }
  catch (error) { state.page -= 1; toast(error.message, true); }
  finally { state.loading = false; }
}

document.addEventListener('click', async event => {
  const viewButton = event.target.closest('[data-view]');
  if (viewButton) { document.querySelector('#sidebar')?.classList.remove('open'); await loadView(viewButton.dataset.view); return; }
  const button = event.target.closest('[data-action]'); if (!button) return;
  const { action, id } = button.dataset;
  try {
    if (action === 'logout') return signOut();
    if (action === 'menu') return document.querySelector('#sidebar')?.classList.toggle('open');
    if (action === 'refresh') return loadView(state.view);
    if (action === 'back-login') return renderLogin('', false, button.dataset.phone || '');
    if (action === 'close-modal') return closeModal();
    if (action === 'create-masjid') return showMasjidForm();
    if (action === 'create-user') return showUserForm();
    if (action === 'approve-request') return await approveRequest(id);
    if (action === 'reject-request') return await rejectRequest(id);
    if (action === 'masjid-detail') return await showMasjidDetail(id);
    if (action === 'clear-masjid-filters') { state.filters = { search:'',status:'ALL',approvalStatus:'ALL',sort:'CREATED_DESC',createdFrom:'',createdTo:'' }; return loadView('masjids'); }
    if (action === 'toggle-masjid') {
      const next = button.dataset.active !== 'true';
      if (!confirm(`${next ? 'Activate' : 'Stop'} this masjid?`)) return;
      await api(`/masjids/admin/${encodeURIComponent(id)}/status`, { method: 'PUT', body: { isActive: next } });
      toast(next ? 'Masjid activated.' : 'Masjid stopped.'); return loadView('masjids');
    }
    if (action === 'delete-masjid') {
      if (!confirm('Permanently delete this masjid and its linked records? This cannot be undone.')) return;
      await api(`/masjids/${encodeURIComponent(id)}`, { method: 'DELETE' }); toast('Masjid deleted.'); return loadView('masjids');
    }
    if (action === 'toggle-user') {
      const next = button.dataset.active !== 'true';
      if (!confirm(`${next ? 'Reactivate' : 'Deactivate'} this account?`)) return;
      await api(`/users/${encodeURIComponent(id)}/status`, { method: 'PATCH', body: { isActive: next } }); toast(next ? 'Account activated.' : 'Account deactivated.'); return loadView('users');
    }
    if (action === 'delete-user') {
      if (!confirm('Delete this user account? This action cannot be undone.')) return;
      await api(`/users/${encodeURIComponent(id)}`, { method: 'DELETE' }); toast('User deleted.'); return loadView('users');
    }
    if (action === 'delete-broadcast') {
      if (!confirm('Delete this broadcast notice?')) return;
      await api(`/announcements/broadcasts/${encodeURIComponent(id)}`, { method: 'DELETE' }); toast('Broadcast deleted.'); return loadView('broadcasts');
    }
  } catch (error) { toast(error.message, true); }
});

document.addEventListener('submit', async event => {
  event.preventDefault(); const form = event.target;
  try {
    if (form.id === 'phone-form') {
      const phone = new FormData(form).get('phone').toString().trim();
      await api('/auth/otp/send', { method: 'POST', auth: false, body: { phone } });
      renderLogin('', true, phone); return;
    }
    if (form.id === 'otp-form') {
      const data = Object.fromEntries(new FormData(form));
      const result = await api('/auth/otp/verify', { method: 'POST', auth: false, body: data });
      const tokens = result.tokens || {}; state.token = tokens.accessToken; state.refreshToken = tokens.refreshToken;
      if (!state.token) throw new Error('The server did not return a sign-in token.');
      sessionStorage.setItem(TOKEN_KEY, state.token); sessionStorage.setItem(REFRESH_KEY, state.refreshToken || '');
      state.user = result.user; const profile = await api('/auth/me'); state.user = profile?.user || profile;
      if (!state.user?.isSuperAdmin) { signOut(false); return renderLogin('This account does not have Super Admin access.'); }
      return loadView('overview');
    }
    if (form.id === 'masjid-filters') {
      const d = Object.fromEntries(new FormData(form)); state.filters = { ...state.filters, ...d }; return loadView('masjids');
    }
    if (form.id === 'user-search') {
      state.userSearch = new FormData(form).get('search').toString().trim(); return loadView('users');
    }
    if (form.id === 'masjid-create-form') {
      const d = Object.fromEntries(new FormData(form));
      for (const key of ['state','phone','mapUrl','adminPhone','adminName']) if (!d[key]) delete d[key];
      await api('/masjids', { method: 'POST', body: d }); closeModal(); toast('Masjid created and approved.'); return loadView(state.view);
    }
    if (form.id === 'user-create-form') {
      const f = new FormData(form); const d = { name: f.get('name').toString().trim(), phone: f.get('phone').toString().trim(), isSuperAdmin: f.get('isSuperAdmin') === 'on' };
      const address = f.get('address').toString().trim(); if (address) d.address = address;
      await api('/users', { method: 'POST', body: d }); closeModal(); toast('User account created.'); return loadView('users');
    }
    if (form.id === 'broadcast-form') {
      const d = Object.fromEntries(new FormData(form));
      await api('/announcements/broadcasts', { method: 'POST', body: { title: d.title.trim(), body: d.body.trim(), targetAudience: d.targetAudience, notifyPush: true } });
      toast('Broadcast saved and sent to the selected audience.'); form.reset(); return loadView('broadcasts');
    }
  } catch (error) {
    const target = form.querySelector('.form-error');
    if (target) target.textContent = error.message;
    else toast(error.message, true);
  }
});

document.addEventListener('scroll', event => {
  if (event.target?.classList?.contains('table-wrap') && event.target.scrollTop + event.target.clientHeight >= event.target.scrollHeight - 100) loadMore();
}, true);

document.addEventListener('keydown', event => { if (event.key === 'Escape') closeModal(); });

initialize();
