// routes/users.js
// No authentication — demo login only.
// Returns user record directly for any of the 5 demo users.

const express = require('express');
const router  = express.Router();
const db      = require('../db');

// GET /api/users/demo  — return all demo users for the login screen
router.get('/demo', async (req, res, next) => {
  try {
    const result = await db.execute(
      `SELECT user_id, name, email, phone, role
       FROM   users
       ORDER BY user_id`
    );
    res.json(result.rows);
  } catch (err) { next(err); }
});

// POST /api/users/login  — demo login, no password check
// Body: { userId: 2 }
router.post('/login', async (req, res, next) => {
  try {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: 'userId required' });

    const result = await db.execute(
      `SELECT user_id, name, email, phone, role
       FROM   users WHERE user_id = :id`,
      [userId]
    );
    if (!result.rows.length) return res.status(404).json({ error: 'User not found' });

    res.json(result.rows[0]);
  } catch (err) { next(err); }
});

module.exports = router;