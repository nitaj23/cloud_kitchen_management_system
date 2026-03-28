// =============================================================
//  src/routes/orders.js
//
//  POST /api/orders            — place a new order
//  GET  /api/orders/active     — kitchen display feed
//  GET  /api/orders/:id        — single order details
//  PUT  /api/orders/:id/next   — advance order status
//  PUT  /api/orders/:id/cancel — cancel an order
// =============================================================

const express  = require('express');
const router   = express.Router();
const oracledb = require('oracledb');


// ── POST /api/orders ──────────────────────────────────────────
// Body: { user_id: 2, items: [ { item_id: 3, quantity: 2 } ] }
//
// Without auth, the frontend passes user_id in the request body.
// When auth is added later, this comes from the JWT instead.
router.post('/', async (req, res, next) => {
    let conn;
    try {
        const { user_id, items } = req.body;

        if (!items || items.length === 0) {
            return res.status(400).json({ error: 'No items in order.' });
        }
        if (!user_id) {
            return res.status(400).json({ error: 'user_id is required.' });
        }

        const itemIds    = items.map(i => i.item_id);
        const quantities = items.map(i => i.quantity);

        conn = await oracledb.getConnection();
        const result = await conn.execute(
            `BEGIN
                pkg_orders.place_order(
                    :user_id,
                    SYS.ODCINUMBERLIST(${itemIds.join(',')}),
                    SYS.ODCINUMBERLIST(${quantities.join(',')}),
                    :order_id
                );
             END;`,
            {
                user_id:  Number(user_id),
                order_id: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER }
            }
        );

        res.status(201).json({
            success:  true,
            order_id: result.outBinds.order_id,
            message:  'Order placed successfully.'
        });

    } catch (err) {
        if (err.message && err.message.includes('ORA-20020')) {
            return res.status(400).json({ error: 'One or more items are not available.' });
        }
        next(err);
    } finally {
        if (conn) await conn.close();
    }
});


// ── GET /api/orders/active ────────────────────────────────────
router.get('/active', async (req, res, next) => {
    let conn;
    try {
        conn = await oracledb.getConnection();
        const result = await conn.execute(
            `BEGIN pkg_orders.get_active_orders(:result); END;`,
            { result: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR } }
        );

        const cursor = result.outBinds.result;
        const rows   = await cursor.getRows();
        await cursor.close();

        res.json({ success: true, data: rows });

    } catch (err) {
        next(err);
    } finally {
        if (conn) await conn.close();
    }
});


// ── GET /api/orders/:id ───────────────────────────────────────
router.get('/:id', async (req, res, next) => {
    let conn;
    try {
        conn = await oracledb.getConnection();

        const orderResult = await conn.execute(
            `SELECT o.order_id, u.name AS customer, o.status,
                    o.total_amount, o.created_at
             FROM   orders o JOIN users u ON o.user_id = u.user_id
             WHERE  o.order_id = :id`,
            { id: Number(req.params.id) },
            { outFormat: oracledb.OUT_FORMAT_OBJECT }
        );

        if (orderResult.rows.length === 0) {
            return res.status(404).json({ error: 'Order not found.' });
        }

        const itemsResult = await conn.execute(
            `SELECT m.name, oi.quantity, oi.unit_price,
                    (oi.quantity * oi.unit_price) AS line_total
             FROM   order_items oi
             JOIN   menu_items m ON oi.item_id = m.item_id
             WHERE  oi.order_id = :id`,
            { id: Number(req.params.id) },
            { outFormat: oracledb.OUT_FORMAT_OBJECT }
        );

        res.json({
            success: true,
            data: {
                ...orderResult.rows[0],
                items: itemsResult.rows
            }
        });

    } catch (err) {
        next(err);
    } finally {
        if (conn) await conn.close();
    }
});


// ── PUT /api/orders/:id/next ──────────────────────────────────
router.put('/:id/next', async (req, res, next) => {
    let conn;
    try {
        conn = await oracledb.getConnection();
        await conn.execute(
            `BEGIN pkg_orders.advance_status(:order_id); END;`,
            { order_id: Number(req.params.id) },
            { autoCommit: true }
        );
        res.json({ success: true, message: 'Order status advanced.' });

    } catch (err) {
        if (err.message && err.message.includes('ORA-20021')) {
            return res.status(400).json({ error: 'Cannot advance this order.' });
        }
        next(err);
    } finally {
        if (conn) await conn.close();
    }
});


// ── PUT /api/orders/:id/cancel ────────────────────────────────
router.put('/:id/cancel', async (req, res, next) => {
    let conn;
    try {
        conn = await oracledb.getConnection();
        await conn.execute(
            `BEGIN pkg_orders.cancel_order(:order_id); END;`,
            { order_id: Number(req.params.id) },
            { autoCommit: true }
        );
        res.json({ success: true, message: 'Order cancelled. Inventory restored.' });

    } catch (err) {
        if (err.message && err.message.includes('ORA-20022')) {
            return res.status(400).json({ error: 'Cannot cancel this order.' });
        }
        next(err);
    } finally {
        if (conn) await conn.close();
    }
});


module.exports = router;
