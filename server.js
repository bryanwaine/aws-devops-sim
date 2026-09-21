const express = require("express");
const app = require("./app");
const port = 3000;

app.listen(port, '0.0.0.0', () => {
  console.log(`Server is running on port http://localhost:${port}`);
});
