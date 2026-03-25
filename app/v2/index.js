const express = require("express");
const os = require("os");
const app = express();
const PORT = process.env.PORT || 3000;
const VERSION = "2.0.0";
const COLOR = "green";

app.use(express.json());

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
          background: linear-gradient(135deg, #064e3b 0%, #10b981 100%);
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
          background: #059669;
          border: 2px solid #6ee7b7;
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
        .new-badge {
          display: inline-block;
          background: #fbbf24;
          color: #1c1917;
          border-radius: 999px;
          padding: 4px 12px;
          font-size: 12px;
          font-weight: 700;
          margin-left: 8px;
          vertical-align: middle;
        }
        .info { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; text-align: left; }
        .info-item { background: rgba(255,255,255,0.08); border-radius: 8px; padding: 12px 16px; }
        .info-label { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; opacity: 0.6; }
        .info-value { font-size: 16px; font-weight: 600; margin-top: 4px; }
        .features {
          margin-top: 24px;
          background: rgba(255,255,255,0.08);
          border-radius: 8px;
          padding: 16px;
          text-align: left;
        }
        .features h3 { font-size: 13px; text-transform: uppercase; letter-spacing: 1px; opacity: 0.6; margin-bottom: 8px; }
        .features ul { list-style: none; }
        .features li { padding: 4px 0; font-size: 14px; }
        .features li::before { content: "✅ "; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="badge">🟢 Green Environment</div>
        <h1>Version ${VERSION} <span class="new-badge">NEW</span></h1>
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
        <div class="features">
          <h3>What's new in v2.0.0</h3>
          <ul>
            <li>Improved performance</li>
            <li>New UI design</li>
            <li>Better health checks</li>
            <li>Zero-downtime deployment</li>
          </ul>
        </div>
      </div>
    </body>
    </html>
  `);
});

app.get("/api/info", (req, res) => {
  res.json({
    version: VERSION,
    color: COLOR,
    hostname: os.hostname(),
    platform: os.platform(),
    nodeVersion: process.version,
    uptime: process.uptime(),
    newFeatures: ["improved-performance", "new-ui", "better-health-checks"],
  });
});

app.listen(PORT, () => {
  console.log(`[${COLOR.toUpperCase()}] App v${VERSION} running on port ${PORT}`);
});
