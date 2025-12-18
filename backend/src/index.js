const express = require("express");
const mysql = require("mysql2/promise");
const cors = require("cors");
require("dotenv").config();

const app = express();

/* =========================
   ENV
========================= */
const PORT = process.env.PORT || 5000;
const NODE_ENV = process.env.NODE_ENV || "development";
const CORS_ORIGIN = process.env.CORS_ORIGIN || "*";

/* =========================
   MIDDLEWARE
========================= */
app.use(express.json());
app.use(
  cors({
    origin: CORS_ORIGIN,
    credentials: true,
  })
);

/* =========================
   DATABASE POOL
========================= */
const pool = mysql.createPool({
  host: process.env.DB_HOST,        // ✅ FIXED
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,

  waitForConnections: true,
  connectionLimit: 5,
  queueLimit: 10,
  connectTimeout: 10000,
});

/* =========================
   INIT DB (NON-BLOCKING)
========================= */
async function initializeDatabase() {
  try {
    const connection = await pool.getConnection();

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) NOT NULL UNIQUE,
        phone VARCHAR(20),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    connection.release();
    console.log("Database tables initialized");
  } catch (err) {
    console.error("Database init error:", err.message);
  }
}

/* =========================
   ROUTES
========================= */
app.get("/health", async (req, res) => {
  try {
    const connection = await pool.getConnection();
    connection.release();
    res.status(200).send("OK");
  } catch {
    res.status(500).send("DB NOT READY");
  }
});

app.get("/api/users", async (req, res) => {
  try {
    const [rows] = await pool.query(
      "SELECT * FROM users ORDER BY created_at DESC"
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post("/api/users", async (req, res) => {
  const { name, email, phone } = req.body;
  if (!name || !email)
    return res.status(400).json({ error: "Name & email required" });

  try {
    const [result] = await pool.execute(
      "INSERT INTO users (name, email, phone) VALUES (?, ?, ?)",
      [name, email, phone || null]
    );
    res.status(201).json({ id: result.insertId });
  } catch (err) {
    if (err.code === "ER_DUP_ENTRY")
      return res.status(400).json({ error: "Email exists" });
    res.status(500).json({ error: err.message });
  }
});

/* =========================
   START SERVER
========================= */
const server = app.listen(PORT, "0.0.0.0", () => {
  console.log(`Backend running on port ${PORT}`);
  console.log(`Environment: ${NODE_ENV}`);
  console.log(`CORS Origin: ${CORS_ORIGIN}`);
  initializeDatabase();
});

/* =========================
   GRACEFUL SHUTDOWN
========================= */
process.on("SIGTERM", async () => {
  console.log("Shutting down...");
  await pool.end();
  server.close(() => process.exit(0));
});
