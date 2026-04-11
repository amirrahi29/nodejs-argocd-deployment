const express = require("express");

const app = express();
const PORT = process.env.PORT || 3000;
const deployEnv = process.env.DEPLOY_ENV || process.env.NODE_ENV || "local";

app.get("/healthz", (_req, res) => {
  res.status(200).json({ status: "ok", deployEnv });   
});

app.get("/", (req, res) => {
  res.type("html").send(`<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>Welcome — ${deployEnv}</title></head>
<body>
  <h1>Welcome — ${deployEnv}... main branch</h1>
  <p><a href="/data">GET /data</a> — JSON response</p>
</body> 
</html>`);
});

app.get("/data", (req, res) => {
  res.json({
    message: "Sample data",
    deployEnv,
    items: [
      { id: 1, name: "Alpha" },
      { id: 2, name: "Beta" },
    ],
    timestamp: new Date().toISOString(),
  });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running at http://0.0.0.0:${PORT}/`);
});
