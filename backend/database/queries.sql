-- =============================================================
--  queries.sql
--  CONCEPTS COVERED:
--    - Intermediate SQL: JOINs, GROUP BY, HAVING, subqueries
--    - Complex Queries: CTEs, window functions, nested subqueries,
--      CASE expressions, ROLLUP
-- =============================================================


-- ═════════════════════════════════════════════════════════════
--  SECTION 1 — INTERMEDIATE SQL
-- ═════════════════════════════════════════════════════════════

-- ── 1.1 INNER JOIN: Full menu with category name ─────────────
-- Shows every available dish alongside its category.
-- INNER JOIN only returns rows that match on both sides.
SELECT
    m.item_id,
    m.name          AS dish,
    m.price,
    c.name          AS category,
    m.is_available
FROM
    menu_items  m
    INNER JOIN categories c ON m.category_id = c.category_id
WHERE
    m.is_available = 'Y'
ORDER BY
    c.name, m.price;


-- ── 1.2 LEFT JOIN: All categories, even empty ones ───────────
-- LEFT JOIN returns ALL rows from the left table (categories)
-- even if no menu items exist for that category yet.
SELECT
    c.name              AS category,
    COUNT(m.item_id)    AS total_items,
    NVL(MIN(m.price), 0) AS cheapest
FROM
    categories  c
    LEFT JOIN menu_items m ON c.category_id = m.category_id
                           AND m.is_available = 'Y'
GROUP BY
    c.name
ORDER BY
    total_items DESC;


-- ── 1.3 GROUP BY + HAVING: Categories with avg price > 150 ──
-- HAVING filters groups (like WHERE but for aggregated results).
SELECT
    c.name          AS category,
    COUNT(m.item_id) AS item_count,
    ROUND(AVG(m.price), 2) AS avg_price,
    MIN(m.price)    AS min_price,
    MAX(m.price)    AS max_price
FROM
    menu_items  m
    JOIN categories c ON m.category_id = c.category_id
WHERE
    m.is_available = 'Y'
GROUP BY
    c.name
HAVING
    AVG(m.price) > 150
ORDER BY
    avg_price DESC;


-- ── 1.4 Multi-table JOIN: Order details ──────────────────────
-- Combines 4 tables to show what a customer ordered.
SELECT
    o.order_id,
    u.name              AS customer,
    u.phone,
    m.name              AS dish,
    oi.quantity,
    oi.unit_price,
    (oi.quantity * oi.unit_price) AS line_total,
    o.status,
    TO_CHAR(o.created_at, 'DD-MON-YYYY HH24:MI') AS ordered_at
FROM
    orders      o
    JOIN users      u  ON o.user_id    = u.user_id
    JOIN order_items oi ON o.order_id  = oi.order_id
    JOIN menu_items m   ON oi.item_id  = m.item_id
ORDER BY
    o.order_id, m.name;


-- ── 1.5 Subquery in WHERE: Items more expensive than average ─
SELECT
    name, price
FROM
    menu_items
WHERE
    price > (
        SELECT AVG(price)
        FROM   menu_items
        WHERE  is_available = 'Y'
    )
ORDER BY
    price DESC;


-- ═════════════════════════════════════════════════════════════
--  SECTION 2 — COMPLEX QUERIES
-- ═════════════════════════════════════════════════════════════

-- ── 2.1 CTE (Common Table Expression) ────────────────────────
-- CTEs make complex queries readable by naming intermediate steps.
-- This finds the top spending customer per month.
WITH monthly_spending AS (
    -- Step 1: total spend per user per month
    SELECT
        u.user_id,
        u.name                              AS customer,
        TO_CHAR(o.created_at, 'YYYY-MM')    AS order_month,
        SUM(o.total_amount)                 AS total_spent
    FROM
        orders o JOIN users u ON o.user_id = u.user_id
    WHERE
        o.status = 'delivered'
    GROUP BY
        u.user_id, u.name, TO_CHAR(o.created_at, 'YYYY-MM')
),
ranked_spending AS (
    -- Step 2: rank customers within each month
    SELECT
        customer,
        order_month,
        total_spent,
        RANK() OVER (
            PARTITION BY order_month
            ORDER BY total_spent DESC
        ) AS spend_rank
    FROM
        monthly_spending
)
-- Step 3: pick only the top spender each month
SELECT customer, order_month, total_spent
FROM   ranked_spending
WHERE  spend_rank = 1
ORDER BY order_month;


-- ── 2.2 Window Functions ─────────────────────────────────────
-- Window functions compute values across a "window" of rows
-- without collapsing them like GROUP BY would.
SELECT
    m.name                                          AS dish,
    c.name                                          AS category,
    m.price,
    ROUND(AVG(m.price) OVER (
        PARTITION BY m.category_id                  -- avg per category
    ), 2)                                           AS category_avg,
    m.price - ROUND(AVG(m.price) OVER (
        PARTITION BY m.category_id
    ), 2)                                           AS diff_from_avg,
    RANK() OVER (
        PARTITION BY m.category_id
        ORDER BY m.price DESC                       -- rank within category
    )                                               AS price_rank,
    ROW_NUMBER() OVER (ORDER BY m.price DESC)       AS overall_rank
FROM
    menu_items  m
    JOIN categories c ON m.category_id = c.category_id
WHERE
    m.is_available = 'Y';


-- ── 2.3 CASE expression ──────────────────────────────────────
-- CASE is SQL's if/else. Used here to label items by price tier.
SELECT
    name,
    price,
    CASE
        WHEN price < 100 THEN 'Budget'
        WHEN price < 200 THEN 'Mid-range'
        WHEN price < 300 THEN 'Premium'
        ELSE                   'Luxury'
    END AS price_tier,
    CASE is_available
        WHEN 'Y' THEN 'Available'
        ELSE           'Unavailable'
    END AS availability
FROM
    menu_items
ORDER BY price;


-- ── 2.4 ROLLUP: Sales summary with subtotals ─────────────────
-- ROLLUP generates subtotal rows automatically.
-- Great for admin reports — shows per-category and grand total.
SELECT
    NVL(c.name, '** GRAND TOTAL **')   AS category,
    NVL(m.name, '  Subtotal')          AS dish,
    SUM(oi.quantity)                    AS units_sold,
    SUM(oi.quantity * oi.unit_price)    AS revenue
FROM
    order_items oi
    JOIN orders     o ON oi.order_id    = o.order_id
    JOIN menu_items m ON oi.item_id     = m.item_id
    JOIN categories c ON m.category_id  = c.category_id
WHERE
    o.status = 'delivered'
GROUP BY
    ROLLUP(c.name, m.name)
ORDER BY
    c.name NULLS LAST, m.name NULLS LAST;


-- ── 2.5 Correlated subquery: Items never ordered ─────────────
-- A correlated subquery references the outer query's row.
-- This finds menu items that have never appeared in any order.
SELECT
    m.item_id,
    m.name,
    m.price
FROM
    menu_items m
WHERE
    NOT EXISTS (
        SELECT 1
        FROM   order_items oi
        WHERE  oi.item_id = m.item_id  -- references outer m
    )
ORDER BY
    m.name;


-- ── 2.6 Kitchen display view ─────────────────────────────────
-- Active orders for the kitchen screen, oldest first.
-- Uses multiple JOINs and a LISTAGG to build an item summary.
SELECT
    o.order_id,
    u.name                  AS customer,
    o.status,
    LISTAGG(
        m.name || ' x' || oi.quantity,
        ', '
    ) WITHIN GROUP (ORDER BY m.name) AS items_summary,
    SUM(oi.quantity * oi.unit_price) AS total,
    TO_CHAR(o.created_at, 'HH24:MI') AS time_placed
FROM
    orders      o
    JOIN users       u  ON o.user_id  = u.user_id
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN menu_items  m  ON oi.item_id = m.item_id
WHERE
    o.status IN ('pending', 'preparing')
GROUP BY
    o.order_id, u.name, o.status, o.created_at
ORDER BY
    o.created_at ASC;


-- ── 2.7 Inventory status report ──────────────────────────────
-- Shows current stock vs threshold with a CASE status label.
SELECT
    ingredient_name,
    quantity        AS current_stock,
    unit,
    low_stock_threshold,
    CASE
        WHEN quantity = 0                         THEN 'Out of stock'
        WHEN quantity <= low_stock_threshold       THEN 'Low stock'
        WHEN quantity <= low_stock_threshold * 2   THEN 'Running low'
        ELSE                                           'Adequate'
    END AS stock_status,
    ROUND((quantity / low_stock_threshold) * 100) AS pct_of_threshold
FROM
    inventory
ORDER BY
    pct_of_threshold ASC;  -- worst stock levels first


-- End of queries.sql
