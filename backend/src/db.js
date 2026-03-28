const oracledb = require('oracledb');

const poolConfig = {
  user          : process.env.DB_USER,
  password      : process.env.DB_PASSWORD,
  connectString : process.env.DB_HOST,
  poolMin       : 2,
  poolMax       : 10,
  poolIncrement : 1,
};

let pool;

async function init() {
  pool = await oracledb.createPool(poolConfig);
  console.log('✅ Oracle connection pool created');
}

async function execute(sql, binds = {}, opts = {}) {
  const conn = await pool.getConnection();
  try {
    const result = await conn.execute(sql, binds, {
      outFormat  : oracledb.OUT_FORMAT_OBJECT,
      autoCommit : true,
      ...opts,
    });
    return result;
  } catch (err) {
    console.error("DB ERROR:");
    console.error("SQL:", sql);
    console.error("BINDS:", binds);
    console.error(err);
    throw err;
  } finally {
    await conn.close();
  }
}

module.exports = {
  init,
  execute,
  get oracledb() { return oracledb; }
};