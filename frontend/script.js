// ─────────────────────────────────────────────────────────────
//  MENU DATA
//
//  Right now this is hardcoded here.
//  In Stage 2 (Node.js backend), you'll replace this entire
//  array with a single fetch call:
//
//    const res  = await fetch('/api/menu');
//    const MENU = await res.json();
//
//  Your Node.js server will query MySQL and return the same
//  structure — so the rest of this file stays exactly the same.
// ─────────────────────────────────────────────────────────────
const MENU = [
  { id: 1, name: "Paneer Tikka",     desc: "Chargrilled cottage cheese, mint chutney",  price: 180, cat: "starters",     emoji: "🧆" },
  { id: 2, name: "Veg Spring Rolls", desc: "Crispy rolls, seasoned vegetables",          price: 140, cat: "starters",     emoji: "🥢" },
  { id: 3, name: "Butter Chicken",   desc: "Tomato-butter gravy, tender chicken",        price: 280, cat: "mains",        emoji: "🍛" },
  { id: 4, name: "Dal Makhani",      desc: "Slow-cooked black lentils, cream",           price: 200, cat: "mains",        emoji: "🫕" },
  { id: 5, name: "Chicken Biryani",  desc: "Basmati rice, saffron, spiced chicken",      price: 320, cat: "rice-noodles", emoji: "🍚" },
  { id: 6, name: "Hakka Noodles",    desc: "Wok-tossed noodles, fresh vegetables",       price: 160, cat: "rice-noodles", emoji: "🍜" },
  { id: 7, name: "Gulab Jamun",      desc: "Milk dumplings in rose-cardamom syrup",      price: 90,  cat: "desserts",     emoji: "🍮" },
  { id: 8, name: "Mango Lassi",      desc: "Chilled yoghurt, Alphonso mangoes",          price: 80,  cat: "drinks",       emoji: "🥭" },
];

// ─────────────────────────────────────────────────────────────
//  STATE
//
//  Two variables that represent the current app state:
//    cart      — what the user has added  { itemId: { item, qty } }
//    activeCat — which filter is selected  e.g. "mains"
//
//  Think of these like global variables in a Python script.
// ─────────────────────────────────────────────────────────────
let cart      = {};
let activeCat = "all";


// ─────────────────────────────────────────────────────────────
//  renderMenu(cat)
//
//  Reads the MENU array, filters by category, and builds the
//  HTML rows that appear on the page.
//
//  Python equivalent:
//    def render_menu(cat):
//        items = MENU if cat == "all" else [m for m in MENU if m["cat"] == cat]
//        for item in items:
//            print(build_row_html(item))
// ─────────────────────────────────────────────────────────────
function renderMenu(cat) {
  const items = cat === "all" ? MENU : MENU.filter(m => m.cat === cat);

  document.getElementById("meta").textContent = `${items.length} item${items.length !== 1 ? "s" : ""}`;

  document.getElementById("menu-list").innerHTML = items.map(m => `
    <div class="menu-row">
      <div class="row-emoji">${m.emoji}</div>
      <div class="row-info">
        <div class="row-name">${m.name}</div>
        <div class="row-desc">${m.desc}</div>
      </div>
      <div class="row-right">
        <span class="row-price">₹${m.price}</span>
        <button
          class="add-btn ${cart[m.id] ? "added" : ""}"
          id="btn-${m.id}"
          onclick="addToCart(${m.id})"
        >
          ${cart[m.id] ? "✓ Added" : "+ Add"}
        </button>
      </div>
    </div>
  `).join("");
}


// ─────────────────────────────────────────────────────────────
//  filter(cat, pillElement)
//
//  Called when a category pill is clicked.
//  Updates which pill is highlighted, then re-renders the list.
// ─────────────────────────────────────────────────────────────
function filter(cat, el) {
  activeCat = cat;
  document.querySelectorAll(".pill").forEach(p => p.classList.remove("active"));
  el.classList.add("active");
  renderMenu(cat);
}


// ─────────────────────────────────────────────────────────────
//  addToCart(id)
//
//  Adds an item to the cart, or increments its quantity if
//  it's already there. Then updates the button and the UI.
// ─────────────────────────────────────────────────────────────
function addToCart(id) {
  const item = MENU.find(m => m.id === id);
  if (!item) return;

  if (cart[id]) {
    cart[id].qty += 1;          // already in cart — bump quantity
  } else {
    cart[id] = { item, qty: 1 }; // new item — add with qty 1
  }

  // Update the button on the menu row
  const btn = document.getElementById(`btn-${id}`);
  if (btn) {
    btn.textContent = "✓ Added";
    btn.classList.add("added");
  }

  updateCartUI();
}


// ─────────────────────────────────────────────────────────────
//  removeFromCart(id)
//
//  Removes an item completely from the cart (regardless of qty).
// ─────────────────────────────────────────────────────────────
function removeFromCart(id) {
  delete cart[id];
  renderMenu(activeCat);   // re-render so the button resets to "+ Add"
  updateCartUI();
}


// ─────────────────────────────────────────────────────────────
//  updateCartUI()
//
//  Redraws everything cart-related:
//    - the badge count on the header button
//    - the items list inside the drawer
//    - the total price
//    - whether the "Place order" button is enabled
// ─────────────────────────────────────────────────────────────
function updateCartUI() {
  const entries  = Object.values(cart);
  const totalQty = entries.reduce((sum, c) => sum + c.qty, 0);
  const totalAmt = entries.reduce((sum, c) => sum + c.item.price * c.qty, 0);

  // Header badge
  document.getElementById("cart-count").textContent = totalQty;

  // Total price
  document.getElementById("total").textContent = `₹${totalAmt}`;

  // Enable / disable the order button
  document.getElementById("order-btn").disabled = entries.length === 0;

  // Drawer item list
  document.getElementById("drawer-items").innerHTML = entries.length === 0
    ? `<p class="empty-msg">Nothing here yet.<br>Add something from the menu!</p>`
    : entries.map(({ item, qty }) => `
        <div class="c-item">
          <div>
            <div class="c-item-name">${item.emoji} ${item.name}${qty > 1 ? ` ×${qty}` : ""}</div>
            <div class="c-item-price">₹${item.price * qty}</div>
          </div>
          <button class="rm-btn" onclick="removeFromCart(${item.id})" title="Remove">✕</button>
        </div>
      `).join("");
}


// ─────────────────────────────────────────────────────────────
//  toggleCart()
//
//  Opens or closes the cart drawer.
//  The "open" class is what triggers the CSS slide animation.
// ─────────────────────────────────────────────────────────────
function toggleCart() {
  document.getElementById("drawer").classList.toggle("open");
  document.getElementById("overlay").classList.toggle("open");
}


// ─────────────────────────────────────────────────────────────
//  placeOrder()
//
//  Currently: clears the cart and shows a success toast.
//
//  ── STAGE 2 UPGRADE ──────────────────────────────────────────
//  When your Node.js backend is ready, replace the body of this
//  function with:
//
//    const res = await fetch('/api/orders', {
//      method:  'POST',
//      headers: { 'Content-Type': 'application/json' },
//      body:    JSON.stringify({ items: cart })
//    });
//    const data = await res.json();
//    console.log('Order ID:', data.orderId);
//
//  That one call sends the cart to Express → MySQL.
//  Everything else below (clearing cart, showing toast) stays.
// ─────────────────────────────────────────────────────────────
function placeOrder() {
  console.log("Order placed:", cart);   // visible in browser DevTools → Console

  cart = {};
  updateCartUI();
  toggleCart();

  const toast = document.getElementById("toast");
  toast.classList.add("show");
  setTimeout(() => toast.classList.remove("show"), 3500);
}


// ─────────────────────────────────────────────────────────────
//  INIT — runs once when the page loads
// ─────────────────────────────────────────────────────────────
renderMenu("all");
