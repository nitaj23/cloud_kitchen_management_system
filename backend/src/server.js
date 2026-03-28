// =============================================================
//  src/server.js
// =============================================================

require('dotenv').config();

const express = require('express');
const cors    = require('cors');
const { initPool, closePool } = require('./db');

const menuRoutes  = require('./routes/menu');
const orderRoutes = require('./routes/orders');

const app  = express();
const PORT = process.env.PORT || 3000;

// ── Middleware ────────────────────────────────────────────────
app.use(cors());
app.use(express.json());

app.use((req, res, next) => {
    console.log(`${req.method}  ${req.path}`);
    next();
});

// ── Routes ────────────────────────────────────────────────────
app.use('/api/menu',   menuRoutes);
app.use('/api/orders', orderRoutes);

// ── Health check ──────────────────────────────────────────────
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date() });
});

// ── Global error handler ──────────────────────────────────────
app.use((err, req, res, next) => {
    console.error('Unhandled error:', err.message);
    res.status(err.status || 500).json({
        error: err.message || 'Internal server error'
    });
});

// ── Start ─────────────────────────────────────────────────────
async function start () {
    await initPool();

    const server = app.listen(PORT, () => {
        console.log(`CKMS backend running on http://localhost:${PORT}`);
    });

    process.on('SIGINT', async () => {
        await closePool();
        server.close();
        process.exit(0);
    });
}

start();
