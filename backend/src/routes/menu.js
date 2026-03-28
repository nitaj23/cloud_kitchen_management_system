// routes/menu.js
const express = require('express');
const router  = express.Router();
const db      = require('../db');

// GET /api/menu?category=mains
router.get('/', async (req, res, next) => {
  try {
    const { category } = req.query;

    let sql, binds;

    if (!category || category === 'all') {
      sql = `
        SELECT m.item_id, m.name, m.description, m.price,
               c.name AS category, m.image_url, m.is_available
        FROM   menu_items m
               JOIN categories c ON m.category_id = c.category_id
        WHERE  m.is_available = 'Y'
        ORDER BY c.name, m.price
      `;
      binds = [];
    } else {
      sql = `
        SELECT m.item_id, m.name, m.description, m.price,
               c.name AS category, m.image_url, m.is_available
        FROM   menu_items m
               JOIN categories c ON m.category_id = c.category_id
        WHERE  m.is_available = 'Y'
          AND  LOWER(c.name) = LOWER(:cat)
        ORDER BY m.price
      `;
      binds = [category];
    }

    const result = await db.execute(sql, binds);
    res.json(result.rows);
  } catch (err) { next(err); }
});

// GET /api/menu/categories
router.get('/categories', async (req, res, next) => {
  try {
    const result = await db.execute(
      `SELECT category_id, name FROM categories ORDER BY name`
    );
    res.json(result.rows);
  } catch (err) { next(err); }
});

module.exports = router;