# 🔵🟢 Blue-Green Deployment

A production-ready blue-green deployment setup for a Node.js web application using Docker, Nginx, GitHub Actions, and Prometheus/Grafana monitoring.

---

## 📐 Architecture

```
                        ┌─────────────────────────────────────┐
                        │           Your Server                │
                        │                                      │
   User Traffic         │  ┌──────────────────────────────┐   │
  ─────────────►  :80   │  │       Nginx (Router)         │   │
                        │  │   Reads: nginx/active.conf   │   │
                        │  └──────────┬───────────────────┘   │
                        │             │ proxy_pass             │
                        │      ┌──────┴───────┐               │
                        │      │              │               │
                        │  ┌───▼────┐    ┌────▼───┐          │
                        │  │  BLUE  │    │ GREEN  │          │
                        │  │  :3000 │    │ :3000  │          │
                        │  │  v1.0  │    │  v2.0  │          │
                        │  └────────┘    └────────┘          │
                        │  (LIVE now)   (idle / next)         │
                        └─────────────────────────────────────┘
```

**The key idea:** Both containers run simultaneously. Nginx points to only ONE at a time via a config symlink. Switching is instant and causes **zero downtime**.

---

## 📁 Project Structure

```
blue-green-deployment/
│
├── app/
│   ├── v1/                     # Blue app (v1.0.0)
│   │   ├── index.js
│   │   ├── package.json
│   │   └── Dockerfile
│   └── v2/                     # Green app (v2.0.0)
│       ├── index.js
│       ├── package.json
│       └── Dockerfile
│
├── nginx/
│   ├── nginx.conf              # Main Nginx config (includes active.conf)
│   ├── blue.conf               # Routes traffic → app-blue:3000
│   ├── green.conf              # Routes traffic → app-green:3000
│   └── active.conf             # Symlink → blue.conf or green.conf
│
├── scripts/
│   ├── deploy.sh               # Full blue-green deploy workflow
│   ├── switch.sh               # Switch traffic only (no rebuild)
│   └── healthcheck.sh          # Poll container until healthy
│
├── monitoring/
│   ├── docker-compose.monitoring.yml
│   └── prometheus.yml
│
├── .github/workflows/
│   └── deploy.yml              # CI/CD pipeline
│
├── docker-compose.yml
├── setup.sh                    # First-time setup
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites

- Docker 24+ and Docker Compose v2+
- Git
- `curl` and `wget` (for health checks)

### Step 1 — Clone & Setup

```bash
git clone https://github.com/YOUR_USERNAME/blue-green-deployment.git
cd blue-green-deployment
chmod +x setup.sh
./setup.sh
```

This will:
1. Check prerequisites
2. Create the `nginx/active.conf` symlink pointing to blue
3. Build and start the **blue** container + Nginx
4. Run health checks

Visit **http://localhost** — you should see the blue (v1.0.0) app.

---

## 🔄 Deployment Workflow

### Deploy a New Version (Blue → Green)

```bash
./scripts/deploy.sh
```

What happens step by step:
```
1. Detect current live env   →  BLUE
2. Build new image           →  app-green:latest
3. Start green container     →  docker run app-green
4. Health check green        →  GET /health × 20 retries
5. Switch Nginx              →  active.conf → green.conf
6. Reload Nginx              →  nginx -s reload  (zero downtime)
7. Stop old blue container   →  docker stop app-blue
```

### Keep Old Container for Instant Rollback

```bash
./scripts/deploy.sh --keep-old
```

The blue container stays running. If something goes wrong after switching to green, you can rollback in ~1 second:

```bash
./scripts/deploy.sh --rollback
```

### Switch Traffic Without Rebuilding

```bash
# Already have both containers running? Just flip the switch:
./scripts/switch.sh green
./scripts/switch.sh blue
```

### Deploy a Specific Version Tag

```bash
./scripts/deploy.sh --version v2.1.0
```

---

## 🧪 Testing the Zero-Downtime Switch

Open two terminals:

**Terminal 1** — continuous traffic:
```bash
while true; do
  curl -s http://localhost/api/info | python3 -m json.tool | grep '"color"'
  sleep 0.5
done
```

**Terminal 2** — trigger the switch:
```bash
./scripts/switch.sh green
```

You'll see output like:
```
"color": "blue"
"color": "blue"
"color": "blue"
"color": "green"    ← instant switch, no errors
"color": "green"
```

---

## 🔍 Health Checks

Every container exposes a `/health` endpoint:

```bash
# Check blue
curl http://localhost:3000/health   # direct (if port exposed)

# Check via Nginx (whichever is active)
curl http://localhost/health

# Check headers to see which env is active
curl -I http://localhost/ | grep X-Active-Env
```

Sample health response:
```json
{
  "status": "healthy",
  "version": "2.0.0",
  "color": "green",
  "hostname": "abc123def456",
  "uptime": 42.5,
  "timestamp": "2025-10-01T12:00:00.000Z"
}
```

---

## 📊 Monitoring Setup

Start the monitoring stack:

```bash
cd monitoring
docker compose -f docker-compose.monitoring.yml up -d
```

| Service    | URL                    | Credentials        |
|------------|------------------------|--------------------|
| Grafana    | http://localhost:3001  | admin / admin123   |
| Prometheus | http://localhost:9090  | —                  |
| cAdvisor   | http://localhost:8080  | —                  |

### Setting Up Grafana Dashboards

1. Open **http://localhost:3001**
2. Go to **Connections → Data Sources → Add data source**
3. Select **Prometheus** → URL: `http://prometheus:9090`
4. Click **Save & Test**

Import recommended dashboards:
- **cAdvisor**: Dashboard ID `14282` (container CPU/memory)
- **Nginx**: Dashboard ID `12708`

### Useful Prometheus Queries

```promql
# Container CPU usage
rate(container_cpu_usage_seconds_total{name=~"app-.*"}[1m])

# Container memory usage
container_memory_usage_bytes{name=~"app-.*"}

# Which containers are up
up{job=~"app-.*"}

# Nginx active connections
nginx_connections_active
```

---

## ⚙️ CI/CD Pipeline (GitHub Actions)

### Setup

1. Go to your GitHub repo → **Settings → Secrets and variables → Actions**
2. Add these secrets:

| Secret           | Value                              |
|------------------|------------------------------------|
| `SERVER_HOST`    | Your server IP or hostname         |
| `SERVER_USER`    | SSH username (e.g. `ubuntu`)       |
| `SERVER_SSH_KEY` | Contents of your private key file  |

3. On your server, add your public key to `~/.ssh/authorized_keys`

### Pipeline Flow

```
git push main
     │
     ▼
 ┌────────┐     ┌───────────────┐     ┌──────────┐     ┌─────────────┐
 │  Test  │────►│ Build & Push  │────►│  Deploy  │────►│ Smoke Test  │
 │        │     │ Docker image  │     │ via SSH  │     │             │
 └────────┘     └───────────────┘     └──────────┘     └──────┬──────┘
                                                               │ fail?
                                                               ▼
                                                         Auto Rollback
```

### Manual Deploy from GitHub UI

1. Go to **Actions → Blue-Green Deploy**
2. Click **Run workflow**
3. Set version tag and rollback options

---

## 🔙 Rollback Procedures

### Instant Rollback (if old container is still running)

```bash
./scripts/deploy.sh --rollback
# or
./scripts/switch.sh blue
```

### Full Rollback (rebuild old version)

```bash
docker build -t app-blue:previous ./app/v1
./scripts/switch.sh blue
```

### Emergency Rollback in CI/CD

The pipeline automatically runs a smoke test after deploy. If it fails, the `rollback` step fires via SSH and switches back — all within the same pipeline run.

---

## 🐛 Troubleshooting

### Nginx fails to reload

```bash
docker exec nginx-proxy nginx -t          # Test config syntax
docker logs nginx-proxy --tail 50         # Check error logs
```

### Container won't become healthy

```bash
docker logs app-green --tail 50           # App startup errors
docker inspect app-green | grep -A5 Health
```

### active.conf symlink broken

```bash
ls -la nginx/
# Fix it:
ln -sf blue.conf nginx/active.conf
```

### Port 80 already in use

```bash
sudo lsof -i :80                          # Find what's using port 80
# Edit docker-compose.yml to use a different port, e.g. "8080:80"
```

---

## 📖 Key Concepts Learned

| Concept | How it's implemented here |
|---|---|
| **Zero-downtime deploy** | Nginx `reload` (not restart) with `nginx -s reload` |
| **Traffic switching** | Symlink swap: `active.conf → blue.conf` or `green.conf` |
| **Health checks** | Docker `HEALTHCHECK` + `/health` HTTP endpoint |
| **Rollback** | `--rollback` flag re-runs switch script in reverse |
| **CI/CD** | GitHub Actions → SSH deploy → smoke test → auto rollback |
| **Monitoring** | Prometheus scrapes metrics, Grafana visualizes them |
