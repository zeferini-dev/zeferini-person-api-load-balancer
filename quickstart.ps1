# PowerShell Quick Start Script for Load Balancer Deployment
# Simplified startup sequence for zeferini-person-api-load-balancer

param(
    [switch]$SkipInfra,
    [switch]$SkipBack,
    [switch]$SkipWait
)

# Colors
function Write-Success {
    Write-Host "✓ $args" -ForegroundColor Green
}

function Write-Info {
    Write-Host "ℹ $args" -ForegroundColor Cyan
}

function Write-Warning {
    Write-Host "⚠ $args" -ForegroundColor Yellow
}

function Write-Error {
    Write-Host "✗ $args" -ForegroundColor Red
}

# Header
Write-Host ""
Write-Host "======================================" -ForegroundColor Yellow
Write-Host "Load Balancer Quick Start" -ForegroundColor Yellow
Write-Host "======================================" -ForegroundColor Yellow
Write-Host ""

# Get paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$infraDir = Join-Path $scriptDir ".." "zeferini-teste-full-infra"

# Step 1: Check prerequisites
Write-Warning "[1/4] Checking prerequisites..."

if (-not (Test-Path $infraDir)) {
    Write-Error "Infrastructure directory not found: $infraDir"
    exit 1
}
Write-Success "Infrastructure directory found"

if (-not (docker --version)) {
    Write-Error "Docker not found"
    exit 1
}
Write-Success "Docker found"

if (-not (docker compose version)) {
    Write-Error "Docker Compose not found"
    exit 1
}
Write-Success "Docker Compose found"

# Step 2: Check if infrastructure is running
Write-Host ""
Write-Warning "[2/4] Checking infrastructure status..."

Push-Location $infraDir

$infraRunning = @(docker compose -f docker-compose-infra.yml ps --services --filter "status=running" 2>$null).Count
$backRunning = @(docker compose -f docker-compose-back.yml ps --services --filter "status=running" 2>$null).Count

if ($infraRunning -gt 0 -or $SkipInfra) {
    Write-Success "Infrastructure status: $infraRunning services running (or skipped)"
} else {
    Write-Info "Starting infrastructure..."
    docker compose -f docker-compose-infra.yml up -d --pull missing
    Write-Success "Infrastructure started"
    if (-not $SkipWait) {
        Write-Warning "  Waiting 30 seconds for databases to initialize..."
        Start-Sleep -Seconds 30
    }
}

if ($backRunning -gt 0 -or $SkipBack) {
    Write-Success "Backend status: $backRunning services running (or skipped)"
} else {
    Write-Info "Starting backend services..."
    docker compose -f docker-compose-back.yml -p zeferini-person-backend up -d --build
    Write-Success "Backend services started"
    if (-not $SkipWait) {
        Write-Warning "  Waiting 20 seconds for APIs to initialize..."
        Start-Sleep -Seconds 20
    }
}

Pop-Location

# Step 3: Start load balancer
Write-Host ""
Write-Warning "[3/4] Starting load balancer..."

Push-Location $scriptDir

docker compose -f docker-compose-load-balancer.yml up -d --build
Write-Success "Load balancer started"

Pop-Location

# Step 4: Verify health
Write-Host ""
Write-Warning "[4/4] Verifying health..."

if (-not $SkipWait) {
    Start-Sleep -Seconds 5
}

$lbHealth = try {
    (Invoke-WebRequest -Uri "http://localhost:8084/health" -UseBasicParsing -ErrorAction Stop).StatusCode
} catch {
    "000"
}

$nestjsHealth = try {
    (Invoke-WebRequest -Uri "http://localhost:3000/health" -UseBasicParsing -ErrorAction Stop).StatusCode
} catch {
    "000"
}

$dotnetHealth = try {
    (Invoke-WebRequest -Uri "http://localhost:3002/health" -UseBasicParsing -ErrorAction Stop).StatusCode
} catch {
    "000"
}

Write-Host ""
Write-Host "Load Balancer (8084):  $lbHealth"
Write-Host "NestJS API (3000):     $nestjsHealth"
Write-Host ".NET API (3002):       $dotnetHealth"

if ($lbHealth -eq "200") {
    Write-Success "Load balancer is healthy!"
} else {
    Write-Warning "Load balancer health check returned $lbHealth"
    Write-Info "Try: docker compose -f docker-compose-load-balancer.yml logs load-balancer"
}

# Summary
Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Access points:"
Write-Host "  Load Balancer:  http://localhost:8084"
Write-Host "  Health Check:   http://localhost:8084/health"
Write-Host "  Nginx Status:   http://localhost:8084/nginx_status"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Test the load balancer: curl http://localhost:8084/api/persons"
Write-Host "  2. Check logs: docker compose -f docker-compose-load-balancer.yml logs -f"
Write-Host "  3. Run tests: .\test-endpoints.sh"
Write-Host ""
