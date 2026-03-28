// server.js — Cloud Kitchen Management System
require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const path    = require('path');
const db      = require('./db');

const menuRouter   = require('./routes/menu');
const ordersRouter = require('./routes/orders');
const usersRouter  = require('./routes/users');

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Serve frontend static files
app.use(express.static(path.join(__dirname, '../../frontend')));

// API routes
app.use('/api/menu',   menuRouter);
app.use('/api/orders', ordersRouter);
app.use('/api/users',  usersRouter);

// Fallback: serve index for any non-API route
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '../../frontend/index.html'));
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('[ERROR]', err.message || err);
  res.status(500).json({ error: err.message || 'Internal server error' });
});

// Start after DB is ready
db.init().then(() => {
  app.listen(PORT, () => {
    console.log(`Cloud Kitchen running on http://localhost:${PORT}`);
  });
}).catch(err => {
  console.error('DB init failed:', err.message);
  process.exit(1);
});