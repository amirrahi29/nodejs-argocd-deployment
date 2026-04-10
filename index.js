const express = require("express");

const app = express();
const PORT = process.env.PORT || 3000;

app.get("/welcome", (req, res) => {
  res.type("text/plain").send("Welcome!");
});

app.get("/data", (req, res) => {
  res.json({
    message: "Sample data",
    items: [
      { id: 1, name: "Alpha" },
      { id: 2, name: "Beta" },
    ],
    timestamp: new Date().toISOString(),
  });
});

app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
});
