const express = require("express");
const helmet = require("helmet");

const app = express();
const port = process.env.PORT || 3000;
const serviceName = process.env.SERVICE_NAME || "aws-platform-api";

app.use(helmet());
app.use(express.json());

app.get("/", (req, res) => {
  res.json({
    service: serviceName,
    message: "AWS platform portfolio API",
    endpoints: ["/health"]
  });
});

app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    service: serviceName,
    timestamp: new Date().toISOString()
  });
});

app.listen(port, () => {
  console.log(`${serviceName} listening on port ${port}`);
});
