# Blue-Green Deployment — Local Machine

A hands-on blue-green deployment project running entirely on your local machine using Docker and Nginx. No cloud account needed. Ship new versions of your app with zero downtime, test the concept end-to-end, and roll back instantly — all from your terminal.

---

## What This Project Does

Blue-green deployment means you always have two versions of your app running side by side:

- **Blue** — the version currently serving traffic (your "live" environment)
- **Green** — the new version you just built, sitting ready but not yet receiving traffic

When you're happy with Green, you flip a single switch in Nginx. Traffic moves over instantly. If something breaks, you flip back. Blue was never touched.

Running this locally lets you understand the full mechanics before ever touching a real server.

---

## How It Works on Your Machine

```
Your browser
     │
     ▼
Nginx (port 80)          ← the traffic switch — one config line controls everything
     │
     ├──► Blue container (port 3001)   ← currently live
     └──► Green container (port 3002)  ← new version, standing by
               │
        Shared volume / SQLite DB      ← both containers read the same data
```

Everything runs in Docker containers. Nginx acts as the load balancer — pointing at Blue or Green depending on which config is active. Switching environments is just swapping one Nginx config file and reloading it.

---

## Prerequisites

You only need two things installed:

- **Docker Desktop** — [download here](https://www.docker.com/products/docker-desktop)
- **Docker Compose** — comes bundled with Docker Desktop

Verify both are working:
```bash
docker --version
docker compose version
```

That's it. No AWS account, no cloud setup, no paid services.

---

## Project Structure

```
.
├── app/
│   ├── Dockerfile          ← builds your app image
│   ├── server.js           ← a simple Node.js app with a /health endpoint
│   └── package.json
├── nginx/
│   ├── blue.conf           ← Nginx config pointing traffic to Blue (port 3001)
│   ├── green.conf          ← Nginx config pointing traffic to Green (port 3002)
│   └── nginx.conf          ← active config (symlink to blue.conf or green.conf)
├── docker-compose.yml      ← spins up Blue, Green, and Nginx together
├── deploy.sh               ← one-command deploy script
├── rollback.sh             ← one-command rollback script
└── README.md
```

---

## Getting Started

### 1. Clone the project and build the images

```bash
git clone https://github.com/your-username/blue-green-local.git
cd blue-green-local

# Build both Blue and Green images
docker compose build
```

### 2. Start everything up

```bash
docker compose up -d
```

This starts three containers:
- `app-blue` on port 3001 (serving live traffic through Nginx)
- `app-green` on port 3002 (standing by)
- `nginx` on port 80 (routing all traffic to Blue by default)

Open your browser at `http://localhost` — you should see the app running.

### 3. Check that everything is healthy

```bash
# Check all containers are running
docker compose ps

# Check Blue's health endpoint directly
curl http://localhost:3001/health

# Check Green's health endpoint directly
curl http://localhost:3002/health

# Check what Nginx is currently serving (should say Blue)
curl http://localhost/health
```

---

## Deploying a New Version

Here's the full blue-green workflow. Walk through it manually the first time so you feel exactly what's happening at each step.

### Step 1 — Make a change to your app

Open `app/server.js` and change the version response:

```js
// Change this line
app.get('/', (req, res) => res.json({ version: 'v1', env: 'blue' }))

// To this
app.get('/', (req, res) => res.json({ version: 'v2', env: 'green' }))
```

### Step 2 — Build the new image for Green

```bash
# Build a new image tagged as v2
docker build -t my-app:v2 ./app

# Update Green's container to use the new image
docker compose stop app-green
docker compose rm -f app-green
IMAGE_TAG=v2 docker compose up -d app-green
```

### Step 3 — Test Green before switching any traffic

Green is running on port 3002 but Nginx is still sending all traffic to Blue. Test it directly:

```bash
# Hit Green directly — no real users see this yet
curl http://localhost:3002/
# Should return: { "version": "v2", "env": "green" }

curl http://localhost:3002/health
# Should return: { "status": "ok" }

# Check what users are still seeing (should still be v1 Blue)
curl http://localhost/
# Should return: { "version": "v1", "env": "blue" }
```

If Green looks good, move to the next step. If something's wrong, just fix it and rebuild — Blue is still serving all traffic.

### Step 4 — Switch traffic to Green

This is the moment. One command swaps Nginx to point at Green:

```bash
# Copy the green config over as the active Nginx config
cp nginx/green.conf nginx/nginx.conf

# Reload Nginx — zero downtime, active connections are not dropped
docker compose exec nginx nginx -s reload
```

Verify the switch worked:

```bash
curl http://localhost/
# Should now return: { "version": "v2", "env": "green" }
```

Traffic is now on Green. Blue is still running but receiving nothing.

### Step 5 — Watch, wait, confirm

Give it a few minutes. Hit the app a few times. Check the logs:

```bash
# Watch Green's logs in real time
docker compose logs -f app-green
```

If everything looks good, Blue has officially been retired for this release. Next time you deploy, Green becomes your new Blue.

---

## One-Command Deploy

Once you're comfortable with the manual steps above, use the deploy script:

```bash
# Deploy a new version to Green and switch traffic automatically
./deploy.sh v2
```

Here's what `deploy.sh` does under the hood:

```bash
#!/bin/bash
set -e   # stop immediately if any command fails

NEW_VERSION=$1

if [ -z "$NEW_VERSION" ]; then
  echo "Usage: ./deploy.sh <version>"
  echo "Example: ./deploy.sh v2"
  exit 1
fi

echo "Building image for version $NEW_VERSION..."
docker build -t my-app:$NEW_VERSION ./app

echo "Starting Green with new version..."
docker compose stop app-green
docker compose rm -f app-green
IMAGE_TAG=$NEW_VERSION docker compose up -d app-green

echo "Waiting for Green to be healthy..."
for i in {1..10}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3002/health)
  if [ "$STATUS" = "200" ]; then
    echo "Green is healthy."
    break
  fi
  echo "Attempt $i/10 — waiting..."
  sleep 2
done

if [ "$STATUS" != "200" ]; then
  echo "Green health check failed. Aborting deployment. Blue is still live."
  exit 1
fi

echo "Switching traffic to Green..."
cp nginx/green.conf nginx/nginx.conf
docker compose exec nginx nginx -s reload

echo "Deployment complete. Green is now live."
echo "Blue is still running as your rollback safety net."
echo "Run ./rollback.sh to switch back if needed."
```

---

## Rolling Back

If something goes wrong after the switch, rolling back takes one command:

```bash
./rollback.sh
```

Here's what `rollback.sh` does:

```bash
#!/bin/bash
echo "Rolling back to Blue..."

cp nginx/blue.conf nginx/nginx.conf
docker compose exec nginx nginx -s reload

echo "Done. Blue is live again."
echo "Current traffic target:"
curl -s http://localhost/health
```

That's it. Nginx reloads in under a second. No containers are restarted. No users experience a gap.

---

## Handling Database Changes

Both Blue and Green containers share the same database. This means if your new version changes the database schema, the old version still needs to be able to read the data — right up until the moment you flip the switch.

The safe approach is called **expand-contract**:

**Step 1 — expand (do this in your current release):**
```sql
-- Add the new column. Old code ignores it. New code uses it.
ALTER TABLE users ADD COLUMN display_name TEXT;
```

**Step 2 — contract (do this in a future release, after Blue is retired):**
```sql
-- Old code is gone. Now safe to clean up.
ALTER TABLE users DROP COLUMN old_name;
```

The rule to memorise: **never drop or rename something in the same release as the code that stops using it.**

---

## Useful Commands

```bash
# See all running containers and their status
docker compose ps

# See live logs from both app containers
docker compose logs -f app-blue app-green

# See which environment Nginx is currently sending traffic to
grep proxy_pass nginx/nginx.conf

# Manually hit Blue and Green directly (bypassing Nginx)
curl http://localhost:3001/   # Blue
curl http://localhost:3002/   # Green

# Rebuild everything from scratch
docker compose down
docker compose build --no-cache
docker compose up -d

# Stop everything
docker compose down
```

---

## The docker-compose.yml

```yaml
version: '3.8'

services:

  app-blue:
    image: my-app:${IMAGE_TAG:-v1}
    container_name: app-blue
    environment:
      - ENV_NAME=blue
      - PORT=3001
    ports:
      - "3001:3001"

  app-green:
    image: my-app:${IMAGE_TAG:-v1}
    container_name: app-green
    environment:
      - ENV_NAME=green
      - PORT=3002
    ports:
      - "3002:3002"

  nginx:
    image: nginx:alpine
    container_name: nginx-router
    ports:
      - "80:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - app-blue
      - app-green
```

## The Nginx Config Files

**nginx/blue.conf** — routes traffic to Blue:
```nginx
upstream app {
    server app-blue:3001;
}

server {
    listen 80;

    location / {
        proxy_pass http://app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**nginx/green.conf** — routes traffic to Green:
```nginx
upstream app {
    server app-green:3002;
}

server {
    listen 80;

    location / {
        proxy_pass http://app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

To switch traffic, you copy one file over `nginx.conf` and reload Nginx. That's the entire mechanism.

---

## Common Issues

**Port 80 is already in use**

Something else on your machine is using port 80 (often Apache or another local server). Either stop that service, or change the Nginx port in `docker-compose.yml` from `"80:80"` to `"8080:80"` and access the app at `http://localhost:8080`.

---

**Green health check keeps failing**

Check the Green container logs to see the actual error:
```bash
docker compose logs app-green
```
Common causes: the app crashed on startup, a missing environment variable, or the `/health` endpoint isn't implemented yet.

---

**Nginx reload says "no such container"**

Make sure Nginx is running:
```bash
docker compose ps nginx
# If it's not running:
docker compose up -d nginx
```

---

**Changes aren't showing after rebuild**

Docker might be using a cached image layer. Force a fresh build:
```bash
docker build --no-cache -t my-app:v2 ./app
```

---

## What to Try Next

Once this is working locally, the natural next steps are:

- **Add a smoke test** — before switching traffic in `deploy.sh`, run a more thorough test against port 3002 (check API responses, not just the health endpoint)
- **Try a failed deployment** — deliberately break the Green app and watch the script abort before switching Nginx
- **Simulate a database migration** — add a column, run both versions, see that they coexist without errors
- **Take it to AWS** — the local setup maps directly to ECS + ALB + CodeDeploy; Blue/Green containers become ECS task definitions, Nginx becomes an Application Load Balancer

---
