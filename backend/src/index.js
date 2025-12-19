const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
require('dotenv').config();

const app = express();

/* ======================
   ENV VARIABLES
====================== */
const PORT = process.env.PORT || 5000;
const NODE_ENV = process.env.NODE_ENV || 'production';

/* ======================
   MIDDLEWARE
====================== */
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ✅ CORS for EC2 deployment
app.use(cors({
  origin: function (origin, callback) {
    const allowedOrigins = [
      'http://13.232.243.78:3000',      // Frontend on EC2
      'http://13.232.243.78',            // Without port
      'http://localhost:3000',           // For testing
    ];

    if (!origin) return callback(null, true);

    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      console.warn(`⚠️ CORS blocked: ${origin}`);
      callback(new Error('Not allowed by CORS'));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  credentials: true
}));

// Request Logger
app.use((req, res, next) => {
  console.log(`${req.method} ${req.path} - ${new Date().toISOString()}`);
  next();
});

/* ======================
   DATABASE POOL
====================== */
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'userdb',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  connectTimeout: 10000,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0
});

/* ======================
   INITIALIZE DATABASE
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
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    `);
    
    conn.release();
    console.log('✅ Database initialized successfully');
  } catch (err) {
    console.error('❌ DB init failed:', err.message);
  }
}

/* ======================
   HEALTH CHECK ROUTES
====================== */
app.get('/health', (req, res) => {
  return res.status(200).json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    env: NODE_ENV
  });
});

app.get('/ready', async (req, res) => {
  try {
    const conn = await pool.getConnection();
    await conn.ping();
    conn.release();
    return res.status(200).json({ 
      status: 'ready', 
      database: 'connected',
      timestamp: new Date().toISOString()
    });
  } catch (err) {
    return res.status(500).json({ 
      status: 'not ready', 
      database: 'disconnected',
      error: err.message 
    });
  }
});

/* ======================
   API ROUTES
====================== */

// GET all users
app.get('/api/users', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM users ORDER BY created_at DESC');
    console.log(`📥 Fetched ${rows.length} users`);
    res.json(rows);
  } catch (err) {
    console.error('❌ GET /api/users error:', err.message);
    res.status(500).json({ error: 'Failed to fetch users', details: err.message });
  }
});

// GET single user
app.get('/api/users/:id', async (req, res) => {
  const { id } = req.params;
  
  try {
    const [rows] = await pool.execute('SELECT * FROM users WHERE id = ?', [id]);
    
    if (rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json(rows[0]);
  } catch (err) {
    console.error('❌ GET /api/users/:id error:', err.message);
    res.status(500).json({ error: 'Failed to fetch user', details: err.message });
  }
});

// POST create user
app.post('/api/users', async (req, res) => {
  const { name, email, phone } = req.body;
  
  if (!name || !email) {
    return res.status(400).json({ error: 'Name and email are required' });
  }
  
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({ error: 'Invalid email format' });
  }
  
  try {
    const [result] = await pool.execute(
      'INSERT INTO users (name, email, phone) VALUES (?, ?, ?)',
      [name.trim(), email.trim().toLowerCase(), phone || null]
    );
    
    console.log(`✅ User created with ID: ${result.insertId}`);
    
    res.status(201).json({ 
      id: result.insertId,
      name,
      email,
      phone,
      message: 'User created successfully'
    });
  } catch (err) {
    console.error('❌ POST /api/users error:', err.message);
    
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'Email already exists' });
    }
    
    res.status(500).json({ error: 'Failed to create user', details: err.message });
  }
});

// PUT update user
app.put('/api/users/:id', async (req, res) => {
  const { id } = req.params;
  const { name, email, phone } = req.body;
  
  if (!name || !email) {
    return res.status(400).json({ error: 'Name and email are required' });
  }
  
  try {
    const [result] = await pool.execute(
      'UPDATE users SET name = ?, email = ?, phone = ? WHERE id = ?',
      [name.trim(), email.trim().toLowerCase(), phone || null, id]
    );
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    console.log(`✅ User ${id} updated`);
    res.json({ message: 'User updated successfully', id });
  } catch (err) {
    console.error('❌ PUT /api/users/:id error:', err.message);
    
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'Email already exists' });
    }
    
    res.status(500).json({ error: 'Failed to update user', details: err.message });
  }
});

// DELETE user
app.delete('/api/users/:id', async (req, res) => {
  const { id } = req.params;
  
  try {
    const [result] = await pool.execute('DELETE FROM users WHERE id = ?', [id]);
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    console.log(`🗑️ User ${id} deleted`);
    res.json({ message: 'User deleted successfully', id });
  } catch (err) {
    console.error('❌ DELETE /api/users/:id error:', err.message);
    res.status(500).json({ error: 'Failed to delete user', details: err.message });
  }
});

/* ======================
   404 HANDLER
====================== */
app.use((req, res) => {
  res.status(404).json({ 
    error: 'Route not found',
    path: req.path,
    method: req.method
  });
});

/* ======================
   ERROR HANDLER
====================== */
app.use((err, req, res, next) => {
  console.error('💥 Unhandled error:', err);
  res.status(500).json({ 
    error: 'Internal server error',
    message: NODE_ENV === 'development' ? err.message : 'Something went wrong'
  });
});

/* ======================
   START SERVER
====================== */
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log('='.repeat(50));
  console.log(`✅ Backend server running on port ${PORT}`);
  console.log(`📍 URL: http://13.232.243.78:${PORT}`);
  console.log(`🌍 Environment: ${NODE_ENV}`);
  console.log('='.repeat(50));
  
  initDB();
});

/* ======================
   GRACEFUL SHUTDOWN
====================== */
process.on('SIGTERM', () => {
  console.log('⚠️ SIGTERM received, closing server...');
  server.close(async () => {
    await pool.end();
    console.log('✅ Server closed gracefully');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('⚠️ SIGINT received, closing server...');
  server.close(async () => {
    await pool.end();
    console.log('✅ Server closed gracefully');
    process.exit(0);
  });
});

module.exports = app;