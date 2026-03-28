// =============================================================
//  src/routes/menu.js
//
//  GET  /api/menu           — fetch full menu (filter by ?category=)
//  GET  /api/menu/:id       — fetch one item
//  PUT  /api/menu/:id/toggle — toggle availability
//  PUT  /api/menu/:id/price  — update price
// =============================================================

const express  = require('express');
const router   = express.Router();
const oracledb = require('oracledb');


// ── GET /api/menu ─────────────────────────────────────────────
router.get('/', async (req, res, next) => {
    let conn;
    try {
        conn = await oracledb.getConnection();
        const category = req.query.category || null;

        const result = await conn.execute(
            `BEGIN pkg_menu.get_menu(:cat, :result); END;`,
            {
                cat:    category,
                result: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR }
            }
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


// ── GET /api/menu/:id ─────────────────────────────────────────
router.get('/:id', async (req, res, next) => {
    let conn;
    try {
        conn = await oracledb.getConnection();

        const result = await conn.execute(
            `BEGIN :result := pkg_menu.get_item(:item_id); END;`,
            {
                item_id: Number(req.params.id),
                result:  { dir: oracledb.BIND_OUT, type: oracledb.CURSOR }
            }
        );

        const cursor = result.outBinds.result;
        const rows   = await cursor.getRows();
        await cursor.close();

        if (rows.length === 0) {
            return res.status(404).json({ error: 'Item not found.' });
        }

        res.json({ success: true, data: rows[0] });

    } catch (err) {
        next(err);
    } finally {
        if (conn) await conn.close();
    }
});


// ── PUT /api/menu/:id/toggle ──────────────────────────────────
router.put('/:id/toggle', async (req, res, next) => {
    let conn;
    try {
        conn = await oracledb.getConnection();
        await conn.execute(
            `BEGIN pkg_menu.toggle_availability(:item_id); END;`,
            { item_id: Number(req.params.id) },
            { autoCommit: true }
        );
        res.json({ success: true, message: 'Availability updated.' });
    } catch (err) {
        next(err);
    } finally {
        if (conn) await conn.close();
    }
});


// ── PUT /api/menu/:id/price ───────────────────────────────────
router.put('/:id/price', async (req, res, next) => {
    let conn;
    try {
        const { price } = req.body;

        if (!price || price <= 0) {
            return res.status(400).json({ error: 'Price must be a positive number.' });
        }

        conn = await oracledb.getConnection();
        const result = await conn.execute(
            `BEGIN :old_price := pkg_menu.update_price(:item_id, :price); END;`,
            {
                item_id:   Number(req.params.id),
                price:     Number(price),
                old_price: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER }
            }
        );

        res.json({
            success:   true,
            old_price: result.outBinds.old_price,
            new_price: price
        });

    } catch (err) {
        next(err);
    } finally {
        if (conn) await conn.close();
    }
});


module.exports = router;
