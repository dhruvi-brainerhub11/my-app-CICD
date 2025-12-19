const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
require('dotenv').config();

const app = express();

/* ======================
   ENV
====================== */
const PORT = process.env.PORT || 5000;
const NODE_ENV = process.env.NODE_ENV || 'development';
const CORS_ORIGIN = process.env.CORS_ORIGIN || '*';

/* ======================
   MIDDLEWARE
====================== */
app.use(cors({
  origin: function (origin, callback) {
    const allowedOrigins = [
      'http://localhost:3000',
      'http://13.232.243.78:3000'
    ];

    // allow requests with no origin (curl, server-to-server)
    if (!origin) return callback(null, true);

    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('CORS not allowed'));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  credentials: true
}));


/* ======================
   DB POOL
====================== */
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  connectTimeout: 10000,
});

/* ======================
   INIT DB (NON-BLOCKING)
====================== */
async function initDB() {
  try {
    const conn = await pool.getConnection();
    await conn.execute(`
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        phone VARCHAR(20),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    conn.release();
    console.log('Database ready');
  } catch (err) {
    console.error('DB init failed:', err.message);
  }
}

/* ======================
   HEALTH (DO NOT TOUCH)
====================== */
app.get('/health', (req, res) => {
  return res.status(200).send('OK');
});

/* ======================
   READINESS (DB CHECK)
====================== */
app.get('/ready', async (req, res) => {
  try {
    const conn = await pool.getConnection();
    conn.release();
    return res.status(200).json({ db: 'connected' });
  } catch {
    return res.status(500).json({ db: 'down' });
  }
});

/* ======================
   ROUTES
====================== */
app.get('/api/users', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM users');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/users', async (req, res) => {
  const { name, email, phone } = req.body;
  if (!name || !email) {
    return res.status(400).json({ error: 'Name & email required' });
  }
  try {
    const [r] = await pool.execute(
      'INSERT INTO users (name,email,phone) VALUES (?,?,?)',
      [name, email, phone || null]
    );
    res.status(201).json({ id: r.insertId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* ======================
   START SERVER
====================== */
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Backend running on ${PORT}`);
  console.log(`ENV: ${NODE_ENV}`);
  initDB();
});
