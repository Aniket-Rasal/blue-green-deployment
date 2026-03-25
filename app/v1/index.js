const express = require("express");
const os = require("os");
const app = express();
const PORT = process.env.PORT || 3000;
const VERSION = "1.0.0";
const COLOR = "blue";

// Middleware
app.use(express.json());

// Health check endpoint — used by deploy script to verify readiness
app.get("/health", (req, res) => {
  res.status(200).json({
    status: "healthy",
    version: VERSION,
    color: COLOR,
    hostname: os.hostname(),
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  });
});

// Main page
app.get("/", (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
      <title>Blue-Green Demo</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: 'Segoe UI', sans-serif;
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          background: linear-gradient(135deg, #1e3a5f 0%, #2563eb 100%);
          color: white;
        }
        .card {
          background: rgba(255,255,255,0.1);
          backdrop-filter: blur(10px);
          border: 1px solid rgba(255,255,255,0.2);
          border-radius: 16px;
          padding: 48px 64px;
          text-align: center;
          box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        .badge {
          display: inline-block;
          background: #2563eb;
          border: 2px solid #93c5fd;
          border-radius: 999px;
          padding: 6px 20px;
          font-size: 13px;
          font-weight: 600;
          letter-spacing: 2px;
          text-transform: uppercase;
          margin-bottom: 24px;
        }
        h1 { font-size: 48px; font-weight: 800; margin-bottom: 12px; }
        .subtitle { font-size: 18px; opacity: 0.8; margin-bottom: 32px; }
        .info { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; text-align: left; }
        .info-item { background: rgba(255,255,255,0.08); border-radius: 8px; padding: 12px 16px; }
        .info-label { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; opacity: 0.6; }
        .info-value { font-size: 16px; font-weight: 600; margin-top: 4px; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="badge">🔵 Blue Environment</div>
        <h1>Version ${VERSION}</h1>
        <p class="subtitle">Blue-Green Deployment Demo</p>
        <div class="info">
          <div class="info-item">
            <div class="info-label">Version</div>
            <div class="info-value">${VERSION}</div>
          </div>
          <div class="info-item">
            <div class="info-label">Environment</div>
            <div class="info-value">${COLOR.toUpperCase()}</div>
          </div>
          <div class="info-item">
            <div class="info-label">Host</div>
            <div class="info-value">${os.hostname()}</div>
          </div>
          <div class="info-item">
            <div class="info-label">Node</div>
            <div class="info-value">${process.version}</div>
          </div>
        </div>
      </div>
    </body>
    </html>
  `);
});

// API info endpoint
app.get("/api/info", (req, res) => {
  res.json({
    version: VERSION,
    color: COLOR,
    hostname: os.hostname(),
    platform: os.platform(),
    nodeVersion: process.version,
    uptime: process.uptime(),
  });
});

app.listen(PORT, () => {
  console.log(`[${COLOR.toUpperCase()}] App v${VERSION} running on port ${PORT}`);
});
