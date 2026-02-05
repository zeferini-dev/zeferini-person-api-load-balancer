# Load Balancer - Quick Reference & Troubleshooting

## ⚡ Quick Commands

### Startup
```bash
# Windows (PowerShell)
.\quickstart.ps1

# Linux/macOS (Bash)
bash quickstart.sh
```

### Management
```bash
# Start
docker compose -f docker-compose-load-balancer.yml up -d --build

# Stop
docker compose -f docker-compose-load-balancer.yml down

# Logs
docker compose -f docker-compose-load-balancer.yml logs -f load-balancer

# Status
docker compose -f docker-compose-load-balancer.yml ps
```

### Testing
```bash
# Health check
curl http://localhost:8084/health

# Nginx status
curl http://localhost:8084/nginx_status

# Roundrobin test
for i in {1..4}; do curl http://localhost:8084/api/persons; done
```

## 🔍 Diagnosis

### Is load balancer running?
```bash
docker ps | grep api-load-balancer
# OR
docker compose -f docker-compose-load-balancer.yml ps
```

### Are backends accessible to load balancer?
```bash
# From inside load-balancer container
docker compose -f docker-compose-load-balancer.yml exec load-balancer bash

# Test DNS resolution
nslookup nestjs-app
nslookup dotnet-app
ping nestjs-app:3000
ping dotnet-app:3002
exit
```

### Network connectivity
```bash
# Check if backends are in the correct network
docker network inspect zeferini-person-backend-backend-network

# Verify load-balancer is connected
docker network inspect zeferini-person-backend-backend-network | grep api-load-balancer
```

### Check Nginx configuration
```bash
# Test Nginx syntax
docker compose -f docker-compose-load-balancer.yml exec load-balancer nginx -t

# View Nginx configuration
docker compose -f docker-compose-load-balancer.yml exec load-balancer cat /etc/nginx/nginx.conf
```

## ❌ Common Problems & Solutions

### ✗ Error: "zeferini-person-backend-backend-network" not found
**Problem:** Network doesn't exist or was created with different project name  
**Solution:**
```bash
# Check if network exists
docker network ls | grep zeferini-person-backend

# If not, run docker-compose-back.yml first
cd ../zeferini-teste-full-infra
docker compose -f docker-compose-back.yml -p zeferini-person-backend up -d --build
```

### ✗ Load balancer starts but doesn't route
**Problem:** Nginx is up but requests fail to reach backends  
**Solution:**
```bash
# 1. Check if backends are running
docker ps | grep -E "(nestjs-app|dotnet-app)"

# 2. Check if they're in the same network
docker exec api-load-balancer nslookup nestjs-app

# 3. View Nginx logs
docker compose -f docker-compose-load-balancer.yml logs load-balancer | tail -20

# 4. Try to curl backend directly
curl http://localhost:3000/health
curl http://localhost:3002/health
```

### ✗ 502 Bad Gateway
**Problem:** Nginx can't connect to upstream servers  
**Solution:**
```bash
# Check if upstreams are reachable
docker exec api-load-balancer wget -q -O- http://nestjs-app:3000/health
docker exec api-load-balancer wget -q -O- http://dotnet-app:3002/health

# If no response, backends may not be healthy
# Restart backends
cd ../zeferini-teste-full-infra
docker compose -f docker-compose-back.yml restart nestjs-app dotnet-app
```

### ✗ Port 8084 already in use
**Problem:** Another process is using port 8084  
**Solution:**
```bash
# Option 1: Kill the process
netstat -ano | findstr :8084
taskkill /PID <PID> /F

# Option 2: Use different port
# Edit .env: LB_PORT=8085
docker compose -f docker-compose-load-balancer.yml up -d --build
```

### ✗ Load balancer container exits immediately
**Problem:** Container crashes on startup  
**Solution:**
```bash
# Check logs
docker compose -f docker-compose-load-balancer.yml logs load-balancer

# Common issues:
# 1. nginx.conf syntax error -> Fix nginx.conf
# 2. Port binding error -> Kill process or use different port
# 3. Network not found -> Run docker-compose-back.yml first
```

### ✗ Nginx returns 404 for all routes
**Problem:** Nginx is configured but doesn't have proper location blocks  
**Solution:**
```bash
# Check nginx.conf
docker compose -f docker-compose-load-balancer.yml exec load-balancer cat /etc/nginx/nginx.conf | grep location

# Ensure you have:
# - location / for catch-all
# - Or specific locations (/api/*, /health, etc)
# - upstream backend_servers defined
```

## 🔄 Restart Scenarios

### Graceful restart (keeps connections)
```bash
docker exec api-load-balancer nginx -s reload
```

### Hard restart (breaks connections)
```bash
docker compose -f docker-compose-load-balancer.yml restart load-balancer
```

### Full reset
```bash
docker compose -f docker-compose-load-balancer.yml down -v
docker compose -f docker-compose-load-balancer.yml up -d --build
```

## 📊 Monitoring

### Real-time metrics
```bash
# Nginx status page (requires stub_status module)
curl http://localhost:8084/nginx_status
# Output: active connections, server accepts, handled requests, requests, etc

# Container stats
docker stats api-load-balancer

# Network traffic
docker stats api-load-balancer --no-stream
```

### Logs analysis
```bash
# Last 20 lines
docker compose -f docker-compose-load-balancer.yml logs --tail=20 load-balancer

# Follow in real-time
docker compose -f docker-compose-load-balancer.yml logs -f load-balancer

# Errors only
docker compose -f docker-compose-load-balancer.yml logs load-balancer | grep error

# From specific time
docker compose -f docker-compose-load-balancer.yml logs --since 5m load-balancer
```

## 🔧 Configuration Changes

### Change port
Edit `.env`:
```env
LB_PORT=8085
```
Then restart:
```bash
docker compose -f docker-compose-load-balancer.yml up -d --build
```

### Change roundrobin to weighted
Edit `nginx.conf`:
```nginx
upstream backend_servers {
    server nestjs-app:3000 weight=2;   # Double traffic
    server dotnet-app:3002 weight=1;
}
```
Then reload:
```bash
docker exec api-load-balancer nginx -s reload
```

### Add new backend
Edit `nginx.conf`:
```nginx
upstream backend_servers {
    server nestjs-app:3000 weight=1;
    server dotnet-app:3002 weight=1;
    server nestjs-app2:3000 weight=1;  # New
}
```
Then reload:
```bash
docker exec api-load-balancer nginx -s reload
```

## 📋 Validation Checklist

- [ ] Docker is running
- [ ] docker-compose-infra.yml is up (check: `docker ps | grep postgres`)
- [ ] docker-compose-back.yml is up (check: `docker ps | grep nestjs-app`)
- [ ] Network exists (check: `docker network ls | grep zeferini-person-backend`)
- [ ] Load balancer is up (check: `docker ps | grep api-load-balancer`)
- [ ] Health check passes (check: `curl http://localhost:8084/health`)
- [ ] Can reach NestJS (check: `curl http://localhost:3000/health`)
- [ ] Can reach .NET (check: `curl http://localhost:3002/health`)

Run validation script:
```bash
bash validate-architecture.sh
```

## 📚 Documentation

- `README.md` - Overview and basic usage
- `DEPLOYMENT.md` - Complete deployment guide
- `ARCHITECTURE.md` - Technical architecture
- `QUICK_REFERENCE.md` - This file

## 🆘 Still Having Issues?

1. Run validation script: `bash validate-architecture.sh`
2. Check all logs:
   ```bash
   docker compose -f docker-compose-load-balancer.yml logs
   cd ../zeferini-teste-full-infra
   docker compose -f docker-compose-back.yml logs
   ```
3. Verify network: `docker network inspect zeferini-person-backend-backend-network`
4. Check if services exist: `docker ps -a | grep -E "(nestjs|dotnet|load)"`
5. Review `ARCHITECTURE.md` for detailed network topology
