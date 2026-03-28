-- =============================================================
--  packages.sql
--  CONCEPT: PROCEDURES, FUNCTIONS AND PACKAGES
--
--  A PACKAGE is a container that groups related procedures and
--  functions together — like a Python module/class.
--
--  Two parts:
--    PACKAGE SPEC   — the public interface (what's visible outside)
--                     Declare procedure/function signatures here.
--    PACKAGE BODY   — the implementation (the actual code)
--
--  Why packages?
--    - Organises related logic in one place
--    - Public spec, private body = encapsulation
--    - Package-level variables persist for the whole session
--    - Only recompile what changed
--
--  We have 3 packages:
--    pkg_menu    — menu management
--    pkg_orders  — order placement and management
--    pkg_reports — analytics and reporting
-- =============================================================


-- ═════════════════════════════════════════════════════════════
--  PACKAGE 1: pkg_menu
-- ═════════════════════════════════════════════════════════════

-- ── Package Spec (public interface) ──────────────────────────
CREATE OR REPLACE PACKAGE pkg_menu AS

    -- Returns the full menu (or filtered by category) as a ref cursor
    PROCEDURE get_menu (
        p_category IN  VARCHAR2 DEFAULT NULL,
        p_result   OUT SYS_REFCURSOR
    );

    -- Returns a single item's details
    FUNCTION get_item (
        p_item_id IN menu_items.item_id%TYPE
    ) RETURN SYS_REFCURSOR;

    -- Toggles an item's availability (Y↔N)
    PROCEDURE toggle_availability (
        p_item_id IN menu_items.item_id%TYPE
    );

    -- Updates an item's price; returns the old price
    FUNCTION update_price (
        p_item_id  IN menu_items.item_id%TYPE,
        p_new_price IN menu_items.price%TYPE
    ) RETURN NUMBER;

END pkg_menu;
/


-- ── Package Body (implementation) ────────────────────────────
CREATE OR REPLACE PACKAGE BODY pkg_menu AS

    PROCEDURE get_menu (
        p_category IN  VARCHAR2 DEFAULT NULL,
        p_result   OUT SYS_REFCURSOR
    ) AS
    BEGIN
        IF p_category IS NULL THEN
            OPEN p_result FOR
                SELECT m.item_id, m.name, m.description, m.price,
                       c.name AS category, m.image_url, m.is_available
                FROM   menu_items m
                       JOIN categories c ON m.category_id = c.category_id
                WHERE  m.is_available = 'Y'
                ORDER BY c.name, m.price;
        ELSE
            OPEN p_result FOR
                SELECT m.item_id, m.name, m.description, m.price,
                       c.name AS category, m.image_url, m.is_available
                FROM   menu_items m
                       JOIN categories c ON m.category_id = c.category_id
                WHERE  m.is_available = 'Y'
                  AND  LOWER(c.name)  = LOWER(p_category)
                ORDER BY m.price;
        END IF;
    END get_menu;


    FUNCTION get_item (
        p_item_id IN menu_items.item_id%TYPE
    ) RETURN SYS_REFCURSOR AS
        v_result SYS_REFCURSOR;
    BEGIN
        OPEN v_result FOR
            SELECT m.item_id, m.name, m.description, m.price,
                   c.name AS category, m.image_url, m.is_available
            FROM   menu_items m
                   JOIN categories c ON m.category_id = c.category_id
            WHERE  m.item_id = p_item_id;
        RETURN v_result;
    END get_item;


    PROCEDURE toggle_availability (
        p_item_id IN menu_items.item_id%TYPE
    ) AS
    BEGIN
        UPDATE menu_items
        SET    is_available = CASE is_available
                                WHEN 'Y' THEN 'N'
                                ELSE          'Y'
                              END
        WHERE  item_id = p_item_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20010, 'Menu item not found: ' || p_item_id);
        END IF;
        COMMIT;
    END toggle_availability;


    FUNCTION update_price (
        p_item_id   IN menu_items.item_id%TYPE,
        p_new_price IN menu_items.price%TYPE
    ) RETURN NUMBER AS
        v_old_price menu_items.price%TYPE;
    BEGIN
        SELECT price INTO v_old_price
        FROM   menu_items WHERE item_id = p_item_id;

        UPDATE menu_items
        SET    price = p_new_price
        WHERE  item_id = p_item_id;

        COMMIT;
        RETURN v_old_price;  -- return what the price was before
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20011, 'Menu item not found: ' || p_item_id);
    END update_price;

END pkg_menu;
/


-- ═════════════════════════════════════════════════════════════
--  PACKAGE 2: pkg_orders
-- ═════════════════════════════════════════════════════════════

CREATE OR REPLACE PACKAGE pkg_orders AS

    -- Place a new order; returns the generated order_id
    PROCEDURE place_order (
        p_user_id    IN  orders.user_id%TYPE,
        p_item_ids   IN  SYS.ODCINUMBERLIST,   -- array of item IDs
        p_quantities IN  SYS.ODCINUMBERLIST,   -- matching quantities
        p_order_id   OUT orders.order_id%TYPE
    );

    -- Advance an order to the next status
    PROCEDURE advance_status (
        p_order_id IN orders.order_id%TYPE
    );

    -- Cancel an order
    PROCEDURE cancel_order (
        p_order_id IN orders.order_id%TYPE
    );

    -- Returns all active orders (for kitchen display)
    PROCEDURE get_active_orders (
        p_result OUT SYS_REFCURSOR
    );

    -- Calculate total for a given order
    FUNCTION calc_total (
        p_order_id IN orders.order_id%TYPE
    ) RETURN NUMBER;

END pkg_orders;
/


CREATE OR REPLACE PACKAGE BODY pkg_orders AS

    PROCEDURE place_order (
        p_user_id    IN  orders.user_id%TYPE,
        p_item_ids   IN  SYS.ODCINUMBERLIST,
        p_quantities IN  SYS.ODCINUMBERLIST,
        p_order_id   OUT orders.order_id%TYPE
    ) AS
        v_total      NUMBER := 0;
        v_price      menu_items.price%TYPE;
        v_available  menu_items.is_available%TYPE;
    BEGIN
        -- Validate all items and compute total
        FOR i IN 1 .. p_item_ids.COUNT LOOP
            SELECT price, is_available
            INTO   v_price, v_available
            FROM   menu_items
            WHERE  item_id = p_item_ids(i);

            IF v_available = 'N' THEN
                RAISE_APPLICATION_ERROR(
                    -20020,
                    'Item ' || p_item_ids(i) || ' is not currently available.'
                );
            END IF;

            v_total := v_total + (v_price * p_quantities(i));
        END LOOP;

        -- Insert the order header
        INSERT INTO orders (user_id, status, total_amount)
        VALUES (p_user_id, 'pending', v_total)
        RETURNING order_id INTO p_order_id;

        -- Insert each line item
        -- trg_snapshot_price trigger auto-fills unit_price
        -- trg_deduct_inventory trigger auto-deducts stock
        FOR i IN 1 .. p_item_ids.COUNT LOOP
            INSERT INTO order_items (order_id, item_id, quantity, unit_price)
            VALUES (p_order_id, p_item_ids(i), p_quantities(i), 0);
        END LOOP;

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END place_order;


    PROCEDURE advance_status (
        p_order_id IN orders.order_id%TYPE
    ) AS
        v_current orders.status%TYPE;
        v_next    orders.status%TYPE;
    BEGIN
        SELECT status INTO v_current
        FROM   orders WHERE order_id = p_order_id;

        -- Determine next valid status
        v_next := CASE v_current
                    WHEN 'pending'   THEN 'preparing'
                    WHEN 'preparing' THEN 'ready'
                    WHEN 'ready'     THEN 'delivered'
                    ELSE NULL
                  END;

        IF v_next IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20021,
                'Order ' || p_order_id || ' cannot be advanced from: ' || v_current
            );
        END IF;

        -- trg_orders_updated_at trigger handles updated_at automatically
        -- trg_validate_status_transition validates the transition
        UPDATE orders SET status = v_next WHERE order_id = p_order_id;
        COMMIT;
    END advance_status;


    PROCEDURE cancel_order (
        p_order_id IN orders.order_id%TYPE
    ) AS
        v_current orders.status%TYPE;
    BEGIN
        SELECT status INTO v_current
        FROM   orders WHERE order_id = p_order_id;

        IF v_current NOT IN ('pending', 'preparing') THEN
            RAISE_APPLICATION_ERROR(
                -20022,
                'Order ' || p_order_id || ' cannot be cancelled at status: ' || v_current
            );
        END IF;

        -- trg_restore_inventory trigger re-stocks ingredients automatically
        UPDATE orders SET status = 'cancelled' WHERE order_id = p_order_id;
        COMMIT;
    END cancel_order;


    PROCEDURE get_active_orders (
        p_result OUT SYS_REFCURSOR
    ) AS
    BEGIN
        OPEN p_result FOR
            SELECT
                o.order_id,
                u.name      AS customer,
                o.status,
                o.total_amount,
                TO_CHAR(o.created_at, 'DD-MON HH24:MI') AS placed_at,
                LISTAGG(m.name || ' x' || oi.quantity, ', ')
                    WITHIN GROUP (ORDER BY m.name) AS items
            FROM
                orders      o
                JOIN users       u  ON o.user_id  = u.user_id
                JOIN order_items oi ON o.order_id = oi.order_id
                JOIN menu_items  m  ON oi.item_id = m.item_id
            WHERE
                o.status IN ('pending', 'preparing')
            GROUP BY
                o.order_id, u.name, o.status, o.total_amount, o.created_at
            ORDER BY
                o.created_at ASC;
    END get_active_orders;


    FUNCTION calc_total (
        p_order_id IN orders.order_id%TYPE
    ) RETURN NUMBER AS
        v_total NUMBER;
    BEGIN
        SELECT NVL(SUM(quantity * unit_price), 0)
        INTO   v_total
        FROM   order_items
        WHERE  order_id = p_order_id;
        RETURN v_total;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN 0;
    END calc_total;

END pkg_orders;
/


-- ═════════════════════════════════════════════════════════════
--  PACKAGE 3: pkg_reports
-- ═════════════════════════════════════════════════════════════

CREATE OR REPLACE PACKAGE pkg_reports AS

    -- Revenue breakdown by category for a date range
    PROCEDURE revenue_by_category (
        p_from   IN DATE DEFAULT TRUNC(SYSDATE, 'MM'),
        p_to     IN DATE DEFAULT SYSDATE,
        p_result OUT SYS_REFCURSOR
    );

    -- Best-selling items
    PROCEDURE top_items (
        p_limit  IN NUMBER DEFAULT 5,
        p_result OUT SYS_REFCURSOR
    );

    -- Returns total revenue for a given day as a scalar
    FUNCTION daily_revenue (
        p_date IN DATE DEFAULT SYSDATE
    ) RETURN NUMBER;

END pkg_reports;
/


CREATE OR REPLACE PACKAGE BODY pkg_reports AS

    PROCEDURE revenue_by_category (
        p_from   IN DATE DEFAULT TRUNC(SYSDATE, 'MM'),
        p_to     IN DATE DEFAULT SYSDATE,
        p_result OUT SYS_REFCURSOR
    ) AS
    BEGIN
        OPEN p_result FOR
            SELECT
                c.name                          AS category,
                COUNT(DISTINCT o.order_id)      AS orders,
                SUM(oi.quantity)                AS units_sold,
                SUM(oi.quantity * oi.unit_price) AS revenue
            FROM
                order_items oi
                JOIN orders     o ON oi.order_id    = o.order_id
                JOIN menu_items m ON oi.item_id     = m.item_id
                JOIN categories c ON m.category_id  = c.category_id
            WHERE
                o.status = 'delivered'
                AND TRUNC(o.created_at) BETWEEN TRUNC(p_from) AND TRUNC(p_to)
            GROUP BY c.name
            ORDER BY revenue DESC;
    END revenue_by_category;


    PROCEDURE top_items (
        p_limit  IN NUMBER DEFAULT 5,
        p_result OUT SYS_REFCURSOR
    ) AS
    BEGIN
        OPEN p_result FOR
            SELECT * FROM (
                SELECT
                    m.name,
                    c.name              AS category,
                    SUM(oi.quantity)    AS total_sold,
                    SUM(oi.quantity * oi.unit_price) AS revenue
                FROM
                    order_items oi
                    JOIN menu_items  m ON oi.item_id    = m.item_id
                    JOIN categories  c ON m.category_id = c.category_id
                    JOIN orders      o ON oi.order_id   = o.order_id
                WHERE
                    o.status = 'delivered'
                GROUP BY m.name, c.name
                ORDER BY total_sold DESC
            )
            WHERE ROWNUM <= p_limit;
    END top_items;


    FUNCTION daily_revenue (
        p_date IN DATE DEFAULT SYSDATE
    ) RETURN NUMBER AS
        v_total NUMBER;
    BEGIN
        SELECT NVL(SUM(total_amount), 0)
        INTO   v_total
        FROM   orders
        WHERE  status = 'delivered'
          AND  TRUNC(created_at) = TRUNC(p_date);
        RETURN v_total;
    END daily_revenue;

END pkg_reports;
/


-- End of packages.sql
