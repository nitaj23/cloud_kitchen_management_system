-- =============================================================
--  triggers.sql
--  CONCEPT: TRIGGERS
--
--  A trigger is a PL/SQL block that fires AUTOMATICALLY when
--  a specific event happens on a table (INSERT, UPDATE, DELETE).
--  You never call a trigger manually — the database fires it.
--
--  Syntax:
--    BEFORE/AFTER  — when to fire (before or after the DML)
--    INSERT/UPDATE/DELETE — which operation triggers it
--    FOR EACH ROW  — fires once per row (vs once per statement)
--    :NEW.col      — the new value being written
--    :OLD.col      — the old value before the change
-- =============================================================


-- ── TRIGGER 1: Auto-update orders.updated_at ─────────────────
-- Fires BEFORE every UPDATE on orders.
-- Sets updated_at to the current time automatically —
-- so Node.js never has to remember to do it.
CREATE OR REPLACE TRIGGER trg_orders_updated_at
BEFORE UPDATE ON orders
FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSDATE;
END;
/


-- ── TRIGGER 2: Deduct inventory on order item insert ─────────
-- Fires AFTER a new row is inserted into order_items.
-- For every ingredient the dish uses, it deducts the
-- required quantity from inventory.
CREATE OR REPLACE TRIGGER trg_deduct_inventory
AFTER INSERT ON order_items
FOR EACH ROW
DECLARE
    v_new_qty   NUMBER;
BEGIN
    -- Loop through every ingredient this menu item uses
    FOR ing IN (
        SELECT
            mii.inventory_id,
            mii.quantity_used,
            i.ingredient_name,
            i.quantity          AS current_stock,
            i.low_stock_threshold
        FROM
            menu_item_inventory mii
            JOIN inventory i ON mii.inventory_id = i.inventory_id
        WHERE
            mii.item_id = :NEW.item_id
    ) LOOP
        -- Deduct: quantity_used × how many portions were ordered
        UPDATE inventory
        SET    quantity   = quantity - (ing.quantity_used * :NEW.quantity),
               updated_at = SYSDATE
        WHERE  inventory_id = ing.inventory_id;

        -- Calculate what the stock will be after deduction
        v_new_qty := ing.current_stock - (ing.quantity_used * :NEW.quantity);

        -- Warn if stock drops to or below threshold
        IF v_new_qty <= ing.low_stock_threshold THEN
            DBMS_OUTPUT.PUT_LINE(
                'WARNING: Low stock for ' || ing.ingredient_name ||
                '. Remaining: ' || v_new_qty
            );
        END IF;
    END LOOP;
END;
/


-- ── TRIGGER 3: Restore inventory on order cancellation ───────
-- Fires AFTER an order status is updated to 'cancelled'.
-- Adds the ingredients back to inventory (reverses deduction).
CREATE OR REPLACE TRIGGER trg_restore_inventory
AFTER UPDATE OF status ON orders
FOR EACH ROW
BEGIN
    -- Only act when status changes TO 'cancelled'
    IF :NEW.status = 'cancelled' AND :OLD.status != 'cancelled' THEN
        FOR oi IN (
            SELECT item_id, quantity FROM order_items
            WHERE  order_id = :NEW.order_id
        ) LOOP
            FOR ing IN (
                SELECT inventory_id, quantity_used
                FROM   menu_item_inventory
                WHERE  item_id = oi.item_id
            ) LOOP
                UPDATE inventory
                SET    quantity   = quantity + (ing.quantity_used * oi.quantity),
                       updated_at = SYSDATE
                WHERE  inventory_id = ing.inventory_id;
            END LOOP;
        END LOOP;
    END IF;
END;
/


-- ── TRIGGER 4: Prevent invalid status transitions ────────────
-- Fires BEFORE an order status update.
-- Enforces the business rule that orders follow a strict path:
--   pending → preparing → ready → delivered
--                       ↘ cancelled (from pending or preparing only)
CREATE OR REPLACE TRIGGER trg_validate_status_transition
BEFORE UPDATE OF status ON orders
FOR EACH ROW
DECLARE
    v_valid BOOLEAN := FALSE;
BEGIN
    -- Define every allowed transition
    IF    :OLD.status = 'pending'   AND :NEW.status IN ('preparing', 'cancelled') THEN v_valid := TRUE;
    ELSIF :OLD.status = 'preparing' AND :NEW.status IN ('ready',     'cancelled') THEN v_valid := TRUE;
    ELSIF :OLD.status = 'ready'     AND :NEW.status = 'delivered'                 THEN v_valid := TRUE;
    END IF;

    IF NOT v_valid THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Invalid status transition: ' || :OLD.status || ' → ' || :NEW.status
        );
    END IF;
END;
/


-- ── TRIGGER 5: Prevent deleting delivered orders ─────────────
-- Fires BEFORE a DELETE on orders.
-- Delivered orders are financial records — they must not be deleted.
CREATE OR REPLACE TRIGGER trg_protect_delivered_orders
BEFORE DELETE ON orders
FOR EACH ROW
BEGIN
    IF :OLD.status = 'delivered' THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'Cannot delete a delivered order. Archive it instead.'
        );
    END IF;
END;
/


-- ── TRIGGER 6: Snapshot price at time of order ───────────────
-- Fires BEFORE an insert into order_items.
-- If unit_price was not supplied, it fetches the current menu
-- price automatically. This preserves the price the customer
-- saw — even if the menu price changes later.
CREATE OR REPLACE TRIGGER trg_snapshot_price
BEFORE INSERT ON order_items
FOR EACH ROW
DECLARE
    v_price menu_items.price%TYPE;
BEGIN
    IF :NEW.unit_price IS NULL OR :NEW.unit_price = 0 THEN
        SELECT price INTO v_price
        FROM   menu_items
        WHERE  item_id = :NEW.item_id;

        :NEW.unit_price := v_price;
    END IF;
END;
/

-- End of triggers.sql
