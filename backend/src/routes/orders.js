const express = require('express');
const router  = express.Router();
const db      = require('../db');


// GET orders
router.get('/', async (req, res, next) => {
  try {
    const { userId } = req.query;
    let query = `
      SELECT o.order_id, o.status, o.total_amount,
             TO_CHAR(o.created_at, 'DD Mon YYYY HH24:MI') AS created_at
      FROM orders o
    `;

    let binds = {};

    // Filter only if userId is provided
    if (userId) {
      query += ` WHERE o.user_id = :user_id`;
      binds.user_id = userId;
    }

    query += ` ORDER BY o.created_at DESC`;

    const result = await db.execute(query, binds);

    const orders = result.rows;

    // Fetch items for each order (unchanged)
    for (const order of orders) {
      const items = await db.execute(
        `SELECT m.name, oi.quantity, oi.unit_price,
                (oi.quantity * oi.unit_price) AS line_total
         FROM order_items oi
         JOIN menu_items m ON oi.item_id = m.item_id
         WHERE oi.order_id = :order_id`,
        { order_id: order.ORDER_ID }
      );
      order.items = items.rows;
    }

    res.json(orders);

  } catch (err) { next(err); }
});


// POST order
router.post('/', async (req, res, next) => {
  try {
    const { userId, items } = req.body;

    if (!userId || !items || items.length === 0) {
      return res.status(400).json({ error: 'userId and items required' });
    }

    let totalAmount = 0;
    const enriched = [];

    for (const { itemId, quantity } of items) {
      const r = await db.execute(
        `SELECT price, is_available, name
         FROM menu_items
         WHERE item_id = :item_id`,
        { item_id: itemId }
      );

      if (!r.rows.length) {
        return res.status(400).json({ error: `Item ${itemId} not found` });
      }

      const item = r.rows[0];

      if (item.IS_AVAILABLE !== 'Y') {
        return res.status(400).json({ error: `${item.NAME} is not available` });
      }

      totalAmount += item.PRICE * quantity;
      enriched.push({ itemId, quantity, price: item.PRICE });
    }

    // Insert order
    await db.execute(
      `INSERT INTO orders (user_id, status, total_amount)
       VALUES (:user_id, 'pending', :total_amount)`,
      {
        user_id: userId,
        total_amount: totalAmount
      }
    );

    // Get latest order ID safely
    const r = await db.execute(
      `SELECT MAX(order_id) AS order_id
       FROM orders
       WHERE user_id = :user_id`,
      { user_id: userId }
    );

    const orderId = r.rows[0].ORDER_ID;

    // Insert items
    for (const { itemId, quantity, price } of enriched) {
      await db.execute(
        `INSERT INTO order_items (order_id, item_id, quantity, unit_price)
         VALUES (:order_id, :item_id, :quantity, :unit_price)`,
        {
          order_id: orderId,
          item_id: itemId,
          quantity: quantity,
          unit_price: price
        }
      );
    }

    res.status(201).json({
      orderId,
      totalAmount,
      status: 'pending'
    });

  } catch (err) {
    console.error("ORDER ERROR:", err);
    next(err);
  }
});


// PATCH order status
router.patch('/:id/status', async (req, res, next) => {
  try {
    const orderId = parseInt(req.params.id);
    const { action } = req.body;

    const current = await db.execute(
      `SELECT status FROM orders WHERE order_id = :order_id`,
      { order_id: orderId }
    );

    if (!current.rows.length) {
      return res.status(404).json({ error: 'Order not found' });
    }

    const status = current.rows[0].STATUS;
    let newStatus;

    if (action === 'cancel') {
      if (!['pending', 'preparing'].includes(status)) {
        return res.status(400).json({ error: `Cannot cancel order in status: ${status}` });
      }
      newStatus = 'cancelled';
    } else {
      const nextMap = {
        pending: 'preparing',
        preparing: 'ready',
        ready: 'delivered'
      };
      newStatus = nextMap[status];
      if (!newStatus) {
        return res.status(400).json({ error: `Cannot advance from: ${status}` });
      }
    }

    await db.execute(
      `UPDATE orders SET status = :status WHERE order_id = :order_id`,
      {
        status: newStatus,
        order_id: orderId
      }
    );

    res.json({ orderId, status: newStatus });

  } catch (err) { next(err); }
});

module.exports = router;