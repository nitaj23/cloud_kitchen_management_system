-- =============================================================
--  seed.sql  (UPDATED)
--  Run AFTER schema.sql.
--  5 demo users (no real auth — demo login screen picks by user_id).
-- =============================================================


-- ── CATEGORIES ───────────────────────────────────────────────
INSERT INTO categories (name) VALUES ('Starters');
INSERT INTO categories (name) VALUES ('Mains');
INSERT INTO categories (name) VALUES ('Rice & Noodles');
INSERT INTO categories (name) VALUES ('Desserts');
INSERT INTO categories (name) VALUES ('Drinks');


-- ── USERS (5 demo users) ─────────────────────────────────────
-- No real passwords needed — login is demo-only (select by user_id)
INSERT INTO users (name, email, password_hash, phone, role)
VALUES ('Admin User',  'admin@ckms.com',   'demo', '9900000001', 'admin');

INSERT INTO users (name, email, password_hash, phone, role)
VALUES ('Jatin R',     'jatin@gmail.com',  'demo', '9900000002', 'customer');

INSERT INTO users (name, email, password_hash, phone, role)
VALUES ('Priya S',     'priya@gmail.com',  'demo', '9900000003', 'customer');

INSERT INTO users (name, email, password_hash, phone, role)
VALUES ('Arjun M',     'arjun@gmail.com',  'demo', '9900000004', 'customer');

INSERT INTO users (name, email, password_hash, phone, role)
VALUES ('Sneha K',     'sneha@gmail.com',  'demo', '9900000005', 'customer');


-- ── MENU ITEMS ───────────────────────────────────────────────
-- category_id: 1=Starters, 2=Mains, 3=Rice&Noodles, 4=Desserts, 5=Drinks
INSERT INTO menu_items (name, description, price, category_id, image_url)
VALUES ('Paneer Tikka', 'Chargrilled cottage cheese, mint chutney', 180, 1,
        'images/paneer-tikka.jpg');

INSERT INTO menu_items (name, description, price, category_id, image_url)
VALUES ('Veg Spring Rolls', 'Crispy rolls, seasoned vegetables', 140, 1,
        'images/spring-rolls.jpg');

INSERT INTO menu_items (name, description, price, category_id, image_url)
VALUES ('Butter Chicken', 'Tomato-butter gravy, tender chicken', 280, 2,
        'images/butter-chicken.jpg');

INSERT INTO menu_items (name, description, price, category_id, image_url)
VALUES ('Dal Makhani', 'Slow-cooked black lentils, cream', 200, 2,
        'images/dal-makhani.jpg');

INSERT INTO menu_items (name, description, price, category_id, image_url)
VALUES ('Chicken Biryani', 'Basmati rice, saffron, spiced chicken', 320, 3,
        'images/biryani.jpg');

INSERT INTO menu_items (name, description, price, category_id, image_url)
VALUES ('Hakka Noodles', 'Wok-tossed noodles, fresh vegetables', 160, 3,
        'images/hakka-noodles.jpg');

INSERT INTO menu_items (name, description, price, category_id, image_url)
VALUES ('Gulab Jamun', 'Milk dumplings in rose-cardamom syrup', 90, 4,
        'images/gulab-jamun.jpg');

INSERT INTO menu_items (name, description, price, category_id, image_url)
VALUES ('Mango Lassi', 'Chilled yoghurt, Alphonso mangoes', 80, 5,
        'images/mango-lassi.jpg');


-- ── INVENTORY ────────────────────────────────────────────────
INSERT INTO inventory (ingredient_name, quantity, unit, low_stock_threshold)
VALUES ('Paneer',         5000,  'grams',  500);

INSERT INTO inventory (ingredient_name, quantity, unit, low_stock_threshold)
VALUES ('Chicken',        8000,  'grams',  1000);

INSERT INTO inventory (ingredient_name, quantity, unit, low_stock_threshold)
VALUES ('Basmati Rice',   10000, 'grams',  2000);

INSERT INTO inventory (ingredient_name, quantity, unit, low_stock_threshold)
VALUES ('Black Lentils',  4000,  'grams',  500);

INSERT INTO inventory (ingredient_name, quantity, unit, low_stock_threshold)
VALUES ('Mango Pulp',     3000,  'ml',     500);

INSERT INTO inventory (ingredient_name, quantity, unit, low_stock_threshold)
VALUES ('Spring Roll Wrappers', 100, 'pieces', 20);

INSERT INTO inventory (ingredient_name, quantity, unit, low_stock_threshold)
VALUES ('Milk Solids',    2000,  'grams',  300);

INSERT INTO inventory (ingredient_name, quantity, unit, low_stock_threshold)
VALUES ('Cream',          2000,  'ml',     300);


-- ── MENU_ITEM_INVENTORY ──────────────────────────────────────
INSERT INTO menu_item_inventory (item_id, inventory_id, quantity_used)
VALUES (1, 1, 200);   -- Paneer Tikka uses 200g Paneer

INSERT INTO menu_item_inventory (item_id, inventory_id, quantity_used)
VALUES (2, 6, 3);     -- Spring Rolls use 3 wrappers

INSERT INTO menu_item_inventory (item_id, inventory_id, quantity_used)
VALUES (3, 2, 250);   -- Butter Chicken uses 250g Chicken

INSERT INTO menu_item_inventory (item_id, inventory_id, quantity_used)
VALUES (3, 8, 50);    -- Butter Chicken also uses 50ml Cream

INSERT INTO menu_item_inventory (item_id, inventory_id, quantity_used)
VALUES (4, 4, 150);   -- Dal Makhani uses 150g Black Lentils

INSERT INTO menu_item_inventory (item_id, inventory_id, quantity_used)
VALUES (4, 8, 30);    -- Dal Makhani also uses 30ml Cream

INSERT INTO menu_item_inventory (item_id, inventory_id, quantity_used)
VALUES (5, 2, 200);   -- Biryani uses 200g Chicken

INSERT INTO menu_item_inventory (item_id, inventory_id, quantity_used)
VALUES (5, 3, 150);   -- Biryani also uses 150g Rice

INSERT INTO menu_item_inventory (item_id, inventory_id, quantity_used)
VALUES (7, 7, 100);   -- Gulab Jamun uses 100g Milk Solids

INSERT INTO menu_item_inventory (item_id, inventory_id, quantity_used)
VALUES (8, 5, 100);   -- Mango Lassi uses 100ml Mango Pulp


-- ── SAMPLE ORDERS ────────────────────────────────────────────
INSERT INTO orders (user_id, status, total_amount)
VALUES (2, 'delivered', 460);

INSERT INTO orders (user_id, status, total_amount)
VALUES (3, 'preparing', 280);

INSERT INTO orders (user_id, status, total_amount)
VALUES (4, 'pending', 400);


-- ── SAMPLE ORDER ITEMS ───────────────────────────────────────
-- Order 1 (Jatin): Paneer Tikka + Chicken Biryani
INSERT INTO order_items (order_id, item_id, quantity, unit_price)
VALUES (1, 1, 1, 180);

INSERT INTO order_items (order_id, item_id, quantity, unit_price)
VALUES (1, 5, 1, 320);

-- Order 2 (Priya): Butter Chicken
INSERT INTO order_items (order_id, item_id, quantity, unit_price)
VALUES (2, 3, 1, 280);

-- Order 3 (Arjun): Dal Makhani + Mango Lassi
INSERT INTO order_items (order_id, item_id, quantity, unit_price)
VALUES (3, 4, 1, 200);

INSERT INTO order_items (order_id, item_id, quantity, unit_price)
VALUES (3, 8, 2, 80);


COMMIT;

-- End of seed.sql