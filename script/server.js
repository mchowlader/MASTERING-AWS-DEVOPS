const express = require("express");
const mysql = require("mysql2"); // Ensure this is correctly imported

const app = express();
const PORT = 3000; // Change port if needed

// Set the IP address manually
const SERVER_IP = "10.62.18.38"; // Replace with your actual IP address

// MySQL Configuration
const db = mysql.createPool({
  connectionLimit: 10,
  host: SERVER_IP,
  user: "app_user",
  password: "your_secure_password",  // Set your MySQL root password here
  database: "practice_app",
  port: 3306
});

// Health Check Endpoint
app.get("/health", (req, res) => {
  db.getConnection((err, connection) => {
    if (err) {
      return res.status(500).json({ status: "DOWN", error: err.message });
    }
    connection.release();
    res.json({ status: "UP" });
  });
});

// Get Users Endpoint
app.get("/users", (req, res) => {
  db.query("SELECT * FROM users", (err, results) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    res.json(results);
  });
});

// Start Server
app.listen(PORT, () => {
  console.log(`Server running on http://${SERVER_IP}:${PORT}`);
});
