// =============================================================
//  src/db.js
//  Oracle database connection using a connection pool.
//
//  A connection pool keeps several connections open and ready
//  so Node.js doesn't have to create a new one for every request.
//  Think of it like a shared taxi rank — grab one when needed,
//  return it when done.
// =============================================================

const oracledb = require('oracledb');

// Use 'thin' mode — no Oracle Client libraries needed locally.
// Switch to 'thick' mode on a production server.
oracledb.initOracleClient(); // comment this out if using thin mode


// Pool configuration — reads from your .env file
const poolConfig = {
    user:             process.env.DB_USER     || 'system',
    password:         process.env.DB_PASSWORD || 'yourpassword',
    connectString:    process.env.DB_HOST     || 'localhost/XEPDB1',
    poolMin:  2,   // minimum connections kept open
    poolMax:  10,  // maximum concurrent connections
    poolIncrement: 2  // add 2 connections when pool is exhausted
};


// Initialise the pool once when the app starts
async function initPool () {
    try {
        await oracledb.createPool(poolConfig);
        console.log('Oracle connection pool created successfully.');
    } catch (err) {
        console.error('Failed to create Oracle pool:', err.message);
        process.exit(1);  // exit if DB connection fails on startup
    }
}


// Helper: run a SQL query and return results
// Usage:
//   const rows = await query('SELECT * FROM menu_items WHERE item_id = :id', { id: 1 });
async function query (sql, params = {}) {
    let conn;
    try {
        conn = await oracledb.getConnection();
        const result = await conn.execute(sql, params, {
            outFormat: oracledb.OUT_FORMAT_OBJECT  // returns plain JS objects
        });
        return result.rows;
    } finally {
        if (conn) await conn.close();  // always return connection to pool
    }
}


// Helper: execute a DML statement (INSERT, UPDATE, DELETE)
// or call a PL/SQL block
// Usage:
//   await execute('UPDATE orders SET status = :s WHERE order_id = :id', { s:'ready', id:1 });
async function execute (sql, params = {}) {
    let conn;
    try {
        conn = await oracledb.getConnection();
        const result = await conn.execute(sql, params, { autoCommit: true });
        return result;
    } finally {
        if (conn) await conn.close();
    }
}


// Helper: call a stored procedure or package procedure
// Usage:
//   const result = await callProc(
//     'pkg_orders.advance_status(:order_id)',
//     { order_id: 5 }
//   );
async function callProc (procCall, params = {}) {
    return execute(`BEGIN ${procCall}; END;`, params);
}


// Close the pool cleanly when the app shuts down
async function closePool () {
    try {
        await oracledb.getPool().close(10);
        console.log('Oracle pool closed.');
    } catch (err) {
        console.error('Error closing pool:', err.message);
    }
}


module.exports = { initPool, query, execute, callProc, closePool };
