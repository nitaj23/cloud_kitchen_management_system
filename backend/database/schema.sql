-- =============================================================
--  CLOUD KITCHEN MANAGEMENT SYSTEM
--  schema.sql
--
--  Run this file first in Oracle SQL Developer or SQL*Plus.
--  It creates every table with full integrity constraints.
--
--  CONCEPTS COVERED:
--    - Primary Keys, Foreign Keys, Unique, Not Null, Check,
--      Default (Integrity Constraints)
--    - ER Model mapped to relational tables
--    - Intermediate SQL: data types, identity columns,
--      cascading deletes, composite keys
-- =============================================================


-- ── Drop tables in reverse dependency order ──────────────────
-- (So we can re-run this script cleanly during development)
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE order_items        CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE orders             CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE menu_item_inventory CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE inventory          CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE menu_items         CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE categories         CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE users              CASCADE CONSTRAINTS';
EXCEPTION
    WHEN OTHERS THEN NULL; -- ignore errors if tables don't exist yet
END;
/


-- ── 1. CATEGORIES ─────────────────────────────────────────────
-- Groups menu items (Starters, Mains, Desserts, etc.)
-- Integrity constraints:
--   PK: category_id     (entity integrity)
--   NOT NULL: name      (every category must have a name)
--   UNIQUE: name        (no duplicate category names)
CREATE TABLE categories (
    category_id   NUMBER          GENERATED ALWAYS AS IDENTITY,
    name          VARCHAR2(50)    NOT NULL,
    -- ── CONSTRAINTS ──
    CONSTRAINT pk_categories  PRIMARY KEY (category_id),
    CONSTRAINT uq_cat_name    UNIQUE      (name)
);


-- ── 2. USERS ──────────────────────────────────────────────────
-- Stores customers and admins in one table.
-- The role column distinguishes them.
-- Integrity constraints:
--   PK: user_id
--   NOT NULL: name, email, password_hash
--   UNIQUE: email         (no two accounts with same email)
--   CHECK: role           (domain constraint — only valid roles)
--   DEFAULT: role, created_at
CREATE TABLE users (
    user_id        NUMBER          GENERATED ALWAYS AS IDENTITY,
    name           VARCHAR2(100)   NOT NULL,
    email          VARCHAR2(150)   NOT NULL,
    password_hash  VARCHAR2(255)   NOT NULL,
    phone          VARCHAR2(15),
    role           VARCHAR2(10)    DEFAULT 'customer' NOT NULL,
    created_at     DATE            DEFAULT SYSDATE,
    -- ── CONSTRAINTS ──
    CONSTRAINT pk_users       PRIMARY KEY (user_id),
    CONSTRAINT uq_user_email  UNIQUE      (email),
    CONSTRAINT chk_user_role  CHECK       (role IN ('customer', 'admin'))
);


-- ── 3. MENU_ITEMS ─────────────────────────────────────────────
-- Every dish on the menu.
-- Integrity constraints:
--   PK: item_id
--   FK: category_id → categories   (referential integrity)
--   NOT NULL: name, price
--   CHECK: price > 0               (no free or negative priced items)
--   CHECK: is_available            (must be Y or N)
--   DEFAULT: is_available = 'Y'
CREATE TABLE menu_items (
    item_id       NUMBER           GENERATED ALWAYS AS IDENTITY,
    name          VARCHAR2(100)    NOT NULL,
    description   VARCHAR2(300),
    price         NUMBER(8, 2)     NOT NULL,
    category_id   NUMBER,
    image_url     VARCHAR2(500),
    is_available  CHAR(1)          DEFAULT 'Y' NOT NULL,
    -- ── CONSTRAINTS ──
    CONSTRAINT pk_menu_items      PRIMARY KEY (item_id),
    CONSTRAINT fk_item_category   FOREIGN KEY (category_id)
                                  REFERENCES  categories(category_id)
                                  ON DELETE SET NULL,
    CONSTRAINT chk_item_price     CHECK (price > 0),
    CONSTRAINT chk_item_available CHECK (is_available IN ('Y', 'N'))
);


-- ── 4. INVENTORY ──────────────────────────────────────────────
-- Tracks stock levels of raw ingredients.
-- Integrity constraints:
--   PK: inventory_id
--   NOT NULL: ingredient_name, quantity, unit, threshold
--   CHECK: quantity >= 0           (can't have negative stock)
--   CHECK: low_stock_threshold > 0
CREATE TABLE inventory (
    inventory_id        NUMBER          GENERATED ALWAYS AS IDENTITY,
    ingredient_name     VARCHAR2(100)   NOT NULL,
    quantity            NUMBER(10, 3)   NOT NULL,
    unit                VARCHAR2(20)    NOT NULL,
    low_stock_threshold NUMBER(10, 3)   NOT NULL,
    updated_at          DATE            DEFAULT SYSDATE,
    -- ── CONSTRAINTS ──
    CONSTRAINT pk_inventory          PRIMARY KEY (inventory_id),
    CONSTRAINT chk_inv_quantity      CHECK (quantity >= 0),
    CONSTRAINT chk_inv_threshold     CHECK (low_stock_threshold > 0)
);


-- ── 5. MENU_ITEM_INVENTORY ────────────────────────────────────
-- Junction table: resolves many-to-many between menu_items and inventory.
-- One dish uses many ingredients; one ingredient goes into many dishes.
-- Integrity constraints:
--   COMPOSITE PK: (item_id, inventory_id)  — prevents duplicate mappings
--   FK: item_id    → menu_items
--   FK: inventory_id → inventory
--   CHECK: quantity_used > 0
CREATE TABLE menu_item_inventory (
    item_id         NUMBER        NOT NULL,
    inventory_id    NUMBER        NOT NULL,
    quantity_used   NUMBER(10, 3) NOT NULL,
    -- ── CONSTRAINTS ──
    CONSTRAINT pk_mii    PRIMARY KEY (item_id, inventory_id),
    CONSTRAINT fk_mii_item  FOREIGN KEY (item_id)
                             REFERENCES  menu_items(item_id)
                             ON DELETE CASCADE,
    CONSTRAINT fk_mii_inv   FOREIGN KEY (inventory_id)
                             REFERENCES  inventory(inventory_id)
                             ON DELETE CASCADE,
    CONSTRAINT chk_mii_qty  CHECK (quantity_used > 0)
);


-- ── 6. ORDERS ─────────────────────────────────────────────────
-- One row per customer order.
-- Status follows a strict lifecycle enforced by CHECK.
-- Integrity constraints:
--   PK: order_id
--   FK: user_id → users
--   NOT NULL: user_id, status, total_amount
--   CHECK: status (domain constraint)
--   CHECK: total_amount >= 0
--   DEFAULT: status, created_at, updated_at
CREATE TABLE orders (
    order_id      NUMBER         GENERATED ALWAYS AS IDENTITY,
    user_id       NUMBER         NOT NULL,
    status        VARCHAR2(20)   DEFAULT 'pending' NOT NULL,
    total_amount  NUMBER(10, 2)  NOT NULL,
    created_at    DATE           DEFAULT SYSDATE,
    updated_at    DATE           DEFAULT SYSDATE,
    -- ── CONSTRAINTS ──
    CONSTRAINT pk_orders          PRIMARY KEY (order_id),
    CONSTRAINT fk_order_user      FOREIGN KEY (user_id)
                                  REFERENCES  users(user_id),
    CONSTRAINT chk_order_status   CHECK (status IN (
                                    'pending', 'preparing',
                                    'ready', 'delivered', 'cancelled'
                                  )),
    CONSTRAINT chk_order_amount   CHECK (total_amount >= 0)
);


-- ── 7. ORDER_ITEMS ────────────────────────────────────────────
-- The individual line items inside each order.
-- Resolves many-to-many between orders and menu_items.
-- Integrity constraints:
--   PK: order_item_id
--   FK: order_id → orders    ON DELETE CASCADE
--       (deleting an order removes its line items automatically)
--   FK: item_id  → menu_items
--   CHECK: quantity > 0
--   CHECK: unit_price > 0     (snapshot of price at order time)
CREATE TABLE order_items (
    order_item_id  NUMBER       GENERATED ALWAYS AS IDENTITY,
    order_id       NUMBER       NOT NULL,
    item_id        NUMBER       NOT NULL,
    quantity       NUMBER       NOT NULL,
    unit_price     NUMBER(8, 2) NOT NULL,
    -- ── CONSTRAINTS ──
    CONSTRAINT pk_order_items     PRIMARY KEY (order_item_id),
    CONSTRAINT fk_oi_order        FOREIGN KEY (order_id)
                                  REFERENCES  orders(order_id)
                                  ON DELETE CASCADE,
    CONSTRAINT fk_oi_item         FOREIGN KEY (item_id)
                                  REFERENCES  menu_items(item_id),
    CONSTRAINT chk_oi_quantity    CHECK (quantity > 0),
    CONSTRAINT chk_oi_price       CHECK (unit_price > 0)
);


-- ── INDEXES ───────────────────────────────────────────────────
-- Indexes speed up frequent lookups.
-- Oracle auto-creates indexes on PKs and UQs,
-- but these cover our most common WHERE clauses.
CREATE INDEX idx_orders_user_id   ON orders(user_id);
CREATE INDEX idx_orders_status    ON orders(status);
CREATE INDEX idx_order_items_oid  ON order_items(order_id);
CREATE INDEX idx_menu_category    ON menu_items(category_id);
CREATE INDEX idx_menu_available   ON menu_items(is_available);


COMMIT;

-- End of schema.sql
