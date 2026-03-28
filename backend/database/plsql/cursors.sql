-- =============================================================
--  cursors.sql
--  CONCEPT: CURSORS
--
--  A cursor is a pointer into the result set of a SQL query.
--  It lets you process rows one at a time — useful when you
--  need to apply logic to each row individually.
--
--  Two types:
--    Implicit cursor — Oracle creates automatically for every
--                      SELECT INTO, INSERT, UPDATE, DELETE
--    Explicit cursor — You declare, open, fetch, and close it
--
--  Lifecycle of an explicit cursor:
--    1. DECLARE  — define the SELECT
--    2. OPEN     — execute the query, populate the result set
--    3. FETCH    — read one row at a time
--    4. CLOSE    — release memory
--
--  Cursor attributes:
--    %FOUND     — TRUE if FETCH returned a row
--    %NOTFOUND  — TRUE if FETCH found no more rows (exit condition)
--    %ROWCOUNT  — number of rows fetched so far
--    %ISOPEN    — TRUE if the cursor is currently open
-- =============================================================


-- ── CURSOR 1: Daily sales report ─────────────────────────────
-- Loops through all delivered orders for a given date
-- and prints an itemised sales report.
CREATE OR REPLACE PROCEDURE cursor_daily_sales (
    p_date IN DATE DEFAULT SYSDATE
) AS
    -- DECLARE the cursor — just a named SELECT, not executed yet
    CURSOR c_sales IS
        SELECT
            m.name                              AS item_name,
            c.name                              AS category,
            SUM(oi.quantity)                    AS units_sold,
            SUM(oi.quantity * oi.unit_price)    AS revenue
        FROM
            order_items oi
            JOIN menu_items  m ON oi.item_id    = m.item_id
            JOIN categories  c ON m.category_id = c.category_id
            JOIN orders      o ON oi.order_id   = o.order_id
        WHERE
            TRUNC(o.created_at) = TRUNC(p_date)
            AND o.status = 'delivered'
        GROUP BY
            m.name, c.name
        ORDER BY
            revenue DESC;

    -- Variables to hold each fetched row
    v_item      VARCHAR2(100);
    v_cat       VARCHAR2(50);
    v_units     NUMBER;
    v_revenue   NUMBER;
    v_grand     NUMBER := 0;
    v_row_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE(
        '=== Daily Sales: ' || TO_CHAR(p_date, 'DD-MON-YYYY') || ' ==='
    );

    OPEN c_sales;  -- OPEN: execute the query

    LOOP
        FETCH c_sales INTO v_item, v_cat, v_units, v_revenue; -- FETCH: get one row
        EXIT WHEN c_sales%NOTFOUND;  -- exit when no more rows

        v_grand     := v_grand + v_revenue;
        v_row_count := c_sales%ROWCOUNT;  -- running count of rows fetched

        DBMS_OUTPUT.PUT_LINE(
            RPAD(v_item, 25) || ' [' || v_cat || ']' ||
            '  Units: ' || v_units ||
            '  Revenue: ₹' || v_revenue
        );
    END LOOP;

    CLOSE c_sales;  -- CLOSE: release memory

    DBMS_OUTPUT.PUT_LINE('---');
    DBMS_OUTPUT.PUT_LINE('Items sold: ' || v_row_count || '  Grand Total: ₹' || v_grand);
END;
/


-- ── CURSOR 2: Cursor FOR loop (simpler syntax) ───────────────
-- Oracle provides a shorthand: the cursor FOR loop.
-- It handles OPEN, FETCH, and CLOSE automatically.
-- Use this whenever you don't need fine-grained control.
CREATE OR REPLACE PROCEDURE cursor_low_stock_report AS
    v_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Low Stock Ingredients ===');

    -- No explicit OPEN/FETCH/CLOSE needed — FOR loop handles it
    FOR ing IN (
        SELECT
            ingredient_name,
            quantity,
            unit,
            low_stock_threshold,
            ROUND((quantity / low_stock_threshold) * 100) AS pct
        FROM
            inventory
        WHERE
            quantity <= low_stock_threshold
        ORDER BY
            quantity ASC
    ) LOOP
        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE(
            RPAD(ing.ingredient_name, 25) ||
            '  Stock: ' || ing.quantity || ' ' || ing.unit ||
            '  (' || ing.pct || '% of threshold)'
        );
    END LOOP;

    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('All ingredients adequately stocked.');
    ELSE
        DBMS_OUTPUT.PUT_LINE(v_count || ' ingredient(s) need restocking.');
    END IF;
END;
/


-- ── CURSOR 3: Cursor with parameters ─────────────────────────
-- Parameterised cursors accept input values, making them
-- reusable for different filter conditions.
CREATE OR REPLACE PROCEDURE cursor_orders_by_status (
    p_status IN orders.status%TYPE
) AS
    -- Parameterised cursor — p_status is passed in when opened
    CURSOR c_orders (p_stat VARCHAR2) IS
        SELECT
            o.order_id,
            u.name      AS customer,
            o.total_amount,
            TO_CHAR(o.created_at, 'HH24:MI') AS time_placed
        FROM
            orders o JOIN users u ON o.user_id = u.user_id
        WHERE
            o.status = p_stat
        ORDER BY
            o.created_at ASC;

    v_order c_orders%ROWTYPE;  -- %ROWTYPE auto-matches cursor's column types
    v_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Orders with status: ' || UPPER(p_status) || ' ===');

    OPEN c_orders(p_status);  -- pass the parameter when opening

    LOOP
        FETCH c_orders INTO v_order;
        EXIT WHEN c_orders%NOTFOUND;

        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE(
            '#' || v_order.order_id ||
            '  Customer: ' || RPAD(v_order.customer, 15) ||
            '  ₹' || v_order.total_amount ||
            '  at ' || v_order.time_placed
        );
    END LOOP;

    CLOSE c_orders;
    DBMS_OUTPUT.PUT_LINE('Total: ' || v_count || ' order(s)');
END;
/


-- ── CURSOR 4: REF CURSOR (dynamic cursor) ────────────────────
-- A REF CURSOR can point to different queries at runtime —
-- useful for returning result sets from procedures to Node.js.
CREATE OR REPLACE PROCEDURE cursor_get_menu (
    p_category_name IN  VARCHAR2,
    p_result        OUT SYS_REFCURSOR  -- Oracle's built-in ref cursor type
) AS
BEGIN
    IF p_category_name IS NULL OR p_category_name = 'all' THEN
        -- Return full menu
        OPEN p_result FOR
            SELECT m.item_id, m.name, m.description, m.price,
                   c.name AS category, m.image_url
            FROM   menu_items m JOIN categories c ON m.category_id = c.category_id
            WHERE  m.is_available = 'Y'
            ORDER BY c.name, m.price;
    ELSE
        -- Return filtered menu
        OPEN p_result FOR
            SELECT m.item_id, m.name, m.description, m.price,
                   c.name AS category, m.image_url
            FROM   menu_items m JOIN categories c ON m.category_id = c.category_id
            WHERE  m.is_available = 'Y'
              AND  LOWER(c.name) = LOWER(p_category_name)
            ORDER BY m.price;
    END IF;
END;
/


-- ── Run the cursor procedures (for testing in SQL Developer) ──
-- SET SERVEROUTPUT ON;
-- EXEC cursor_daily_sales(SYSDATE);
-- EXEC cursor_low_stock_report;
-- EXEC cursor_orders_by_status('pending');

-- End of cursors.sql
