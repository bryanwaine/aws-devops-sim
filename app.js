const express = require("express");
const app = express();
const APP_VERSION = "v1.0.0";

app.get("/", (req, res) => {
  res.json({ appVersion: APP_VERSION });
});

app.get("/health", (req, res) => {
  res.json({ status: "Healthy" });
});

module.exports = app; 