// script.js — Cloud Kitchen (connected to Express + Oracle)

const API = '';   // same-origin (Express serves this file)

// ─── Auth guard ───────────────────────────────────────────────
const stored = sessionStorage.getItem('ckms_user');
if (!stored) { window.location.replace('login.html'); }
const CURRENT_USER = JSON.parse(stored);
const isAdmin = CURRENT_USER.id === 1;

// ─── State ───────────────────────────────────────────────────
let MENU      = [];
let cart      = {};
let activeCat = 'all';

// ─── Init ─────────────────────────────────────────────────────
function initHeader() {
  const name   = CURRENT_USER.name;
  const initials = name.split(' ').map(w => w[0]).join('').slice(0,2).toUpperCase();
  document.getElementById('user-avatar').textContent = initials;
  document.getElementById('user-name').textContent   = name;
}

function logout() {
  sessionStorage.removeItem('ckms_user');
  window.location.replace('login.html');
}

// ─── Menu ─────────────────────────────────────────────────────
async function loadMenu(category = 'all') {
  document.getElementById('menu-list').innerHTML = '<div class="loading">Loading…</div>';
  try {
    const url = category === 'all'
      ? `${API}/api/menu`
      : `${API}/api/menu?category=${encodeURIComponent(category)}`;
    const res  = await fetch(url);
    MENU = await res.json();
    renderMenu();
  } catch (e) {
    document.getElementById('menu-list').innerHTML =
      '<div class="loading error">Failed to load menu. Is the server running?</div>';
  }
}

function renderMenu() {
  const items = MENU;
  document.getElementById('meta').textContent =
    `${items.length} item${items.length !== 1 ? 's' : ''}`;

  document.getElementById('menu-list').innerHTML = items.map(m => {
    const id  = m.ITEM_ID;
    const qty = cart[id] ? cart[id].qty : 0;

    const control = qty === 0
      ? `<button class="add-btn" id="btn-${id}" onclick="addToCart(${id})">+ Add</button>`
      : `<div class="qty-stepper" id="btn-${id}">
           <button class="qty-btn" onclick="decreaseQty(${id})">−</button>
           <span class="qty-num">${qty}</span>
           <button class="qty-btn" onclick="increaseQty(${id})">+</button>
         </div>`;

    const img = m.IMAGE_URL
      ? m.IMAGE_URL
      : `https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=120&q=80`;

    return `
      <div class="menu-row">
        <img class="row-img" src="${img}" alt="${m.NAME}"
             onerror="this.src='https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=120&q=80'"/>
        <div class="row-info">
          <div class="row-name">${m.NAME}</div>
          <div class="row-desc">${m.DESCRIPTION || ''}</div>
          <span class="cat-badge">${m.CATEGORY}</span>
        </div>
        <div class="row-right">
          <span class="row-price">₹${m.PRICE}</span>
          ${control}
        </div>
      </div>
    `;
  }).join('');
}

function filter(cat, el) {
  activeCat = cat;
  document.querySelectorAll('.pill').forEach(p => p.classList.remove('active'));
  el.classList.add('active');
  loadMenu(cat);
}

// ─── Cart ─────────────────────────────────────────────────────
function addToCart(id) {
  const item = MENU.find(m => m.ITEM_ID === id);
  if (!item) return;
  cart[id] = { item, qty: 1 };
  renderMenu();
  updateCartUI();
}

function increaseQty(id) {
  if (!cart[id]) return;
  cart[id].qty += 1;
  const s = document.getElementById(`btn-${id}`);
  if (s) s.querySelector('.qty-num').textContent = cart[id].qty;
  updateCartUI();
}

function decreaseQty(id) {
  if (!cart[id]) return;
  cart[id].qty -= 1;
  if (cart[id].qty === 0) {
    delete cart[id];
    renderMenu();
  } else {
    const s = document.getElementById(`btn-${id}`);
    if (s) s.querySelector('.qty-num').textContent = cart[id].qty;
  }
  updateCartUI();
}

function removeFromCart(id) {
  delete cart[id];
  renderMenu();
  updateCartUI();
}

function updateCartUI() {
  const entries  = Object.values(cart);
  const totalQty = entries.reduce((s, c) => s + c.qty, 0);
  const totalAmt = entries.reduce((s, c) => s + c.item.PRICE * c.qty, 0);

  document.getElementById('cart-count').textContent = totalQty;
  document.getElementById('total').textContent = `₹${totalAmt}`;
  document.getElementById('order-btn').disabled = entries.length === 0;

  document.getElementById('drawer-items').innerHTML = entries.length === 0
    ? `<p class="empty-msg">Nothing here yet.<br>Add something from the menu!</p>`
    : entries.map(({ item, qty }) => `
        <div class="c-item">
          <div>
            <div class="c-item-name">${item.NAME}${qty > 1 ? ` ×${qty}` : ''}</div>
            <div class="c-item-price">₹${item.PRICE * qty}</div>
          </div>
          <button class="rm-btn" onclick="removeFromCart(${item.ITEM_ID})" title="Remove">✕</button>
        </div>
      `).join('');
}

// ─── Place Order ──────────────────────────────────────────────
async function placeOrder() {
  const entries = Object.values(cart);
  if (!entries.length) return;

  const btn = document.getElementById('order-btn');
  btn.disabled = true;
  btn.textContent = 'Placing…';

  try {
    const payload = {
      userId: CURRENT_USER.id,
      items : entries.map(({ item, qty }) => ({
        itemId  : item.ITEM_ID,
        quantity: qty,
      })),
    };

    const res  = await fetch(`${API}/api/orders`, {
      method : 'POST',
      headers: { 'Content-Type': 'application/json' },
      body   : JSON.stringify(payload),
    });
    const data = await res.json();

    if (!res.ok) throw new Error(data.error || 'Order failed');

    cart = {};
    updateCartUI();
    closeAll();
    showToast(`Order #${data.orderId} placed! Total ₹${data.totalAmount}`);
  } catch (e) {
    showToast('Error: ' + e.message, true);
    btn.disabled = false;
  }
  btn.textContent = 'Place order';
}

async function updateOrder(orderId, action) {
  try {
    const res = await fetch(`/api/orders/${orderId}/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action })
    });

    const data = await res.json();

    if (!res.ok) {
      showToast(data.error || 'Update failed', true);
      return;
    }

    showToast(`Order #${orderId}: ${data.status}`);

    // Refresh orders after update
    loadOrders();

  } catch (err) {
    showToast(err.message, true);
  }
}

// ─── My Orders ────────────────────────────────────────────────
async function toggleOrders() {
  const drawer = document.getElementById('orders-drawer');
  const isOpen = drawer.classList.contains('open');

  closeAll();
  if (!isOpen) {
    drawer.classList.add('open');
    document.getElementById('overlay').classList.add('open');
    await loadOrders();
  }
}

async function loadOrders() {
  const body = document.getElementById('orders-body');
  body.innerHTML = '<div class="loading">Loading orders…</div>';

  try {
    // Admin sees all orders, user sees only their own
    const url = isAdmin
      ? `${API}/api/orders`
      : `${API}/api/orders?userId=${CURRENT_USER.id}`;

    const res    = await fetch(url);
    const orders = await res.json();

    if (!orders.length) {
      body.innerHTML = '<p class="empty-msg">No orders yet.</p>';
      return;
    }

    const statusColor = {
      pending  : '#F59E0B',
      preparing: '#3B82F6',
      ready    : '#8B5CF6',
      delivered: '#10B981',
      cancelled: '#6B7280',
    };

    body.innerHTML = orders.map(o => {

      const nextAction = {
        pending: 'Start Preparing',
        preparing: 'Mark Ready',
        ready: 'Mark Delivered'
      };

      let actionBtn = '';
      let cancelBtn = '';

      // Admin-only controls
      if (isAdmin) {
        if (nextAction[o.STATUS]) {
          actionBtn = `
            <button class="order-action-btn"
              onclick="updateOrder(${o.ORDER_ID}, 'advance')">
              ⚡ ${nextAction[o.STATUS]}
            </button>
          `;
        }

        if (o.STATUS === 'pending' || o.STATUS === 'preparing') {
          cancelBtn = `
            <button class="order-cancel-btn"
              onclick="updateOrder(${o.ORDER_ID}, 'cancel')">
              ✖ Cancel
            </button>
          `;
        }
      }

      return `
        <div class="order-card">
          <div class="order-card-head">
            <span class="order-id">#${o.ORDER_ID}</span>
            <span class="order-status"
              style="color:${statusColor[o.STATUS] || '#6B7280'}">
              ${o.STATUS}
            </span>
          </div>

          ${isAdmin && o.USER_NAME ? `
            <div style="font-size:0.75rem; color:#888; margin-bottom:6px;">
              by ${o.USER_NAME}
            </div>
          ` : ''}

          <div class="order-items-list">
            ${(o.items || []).map(i =>
              `<span>${i.NAME} ×${i.QUANTITY}</span>`
            ).join(' · ')}
          </div>

          <div class="order-card-foot">
            <span class="order-date">${o.CREATED_AT}</span>
            <span class="order-total">₹${o.TOTAL_AMOUNT}</span>
          </div>

          ${isAdmin ? `
            <div class="order-actions">
              ${actionBtn}
              ${cancelBtn}
            </div>
          ` : ''}
        </div>
      `;
    }).join('');

  } catch (e) {
    body.innerHTML = '<p class="empty-msg">Could not load orders.</p>';
  }
}

// ─── Drawer helpers ───────────────────────────────────────────
function toggleCart() {
  const drawer  = document.getElementById('drawer');
  const isOpen  = drawer.classList.contains('open');
  closeAll();
  if (!isOpen) {
    drawer.classList.add('open');
    document.getElementById('overlay').classList.add('open');
  }
}

function closeAll() {
  document.getElementById('drawer').classList.remove('open');
  document.getElementById('orders-drawer').classList.remove('open');
  document.getElementById('overlay').classList.remove('open');
}

// ─── Toast ────────────────────────────────────────────────────
function showToast(msg, isError = false) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.style.background = isError ? '#DC2626' : '#2C1810';
  t.classList.add('show');
  setTimeout(() => t.classList.remove('show'), 3800);
}

// ─── Boot ─────────────────────────────────────────────────────
initHeader();
loadMenu();

if (!isAdmin) {
  setInterval(() => {
    const drawer = document.getElementById('orders-drawer');
    if (drawer.classList.contains('open')) {
      loadOrders();
    }
  }, 5000);
}