#!/bin/bash

# Quick Start Script for Load Balancer Deployment
# Simplified startup sequence for zeferini-person-api-load-balancer

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}======================================${NC}"
echo -e "${YELLOW}Load Balancer Quick Start${NC}"
echo -e "${YELLOW}======================================${NC}"
echo ""

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFRA_DIR="$SCRIPT_DIR/../zeferini-teste-full-infra"

# Step 1: Check prerequisites
echo -e "${YELLOW}[1/4] Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker found${NC}"

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}✗ Docker Compose not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose found${NC}"

if [ ! -d "$INFRA_DIR" ]; then
    echo -e "${RED}✗ Infrastructure directory not found: $INFRA_DIR${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Infrastructure directory found${NC}"

# Step 2: Check if infrastructure is running
echo ""
echo -e "${YELLOW}[2/4] Checking infrastructure status...${NC}"

cd "$INFRA_DIR"

INFRA_RUNNING=$(docker compose -f docker-compose-infra.yml ps --services --filter "status=running" 2>/dev/null | wc -l)
BACK_RUNNING=$(docker compose -f docker-compose-back.yml ps --services --filter "status=running" 2>/dev/null | wc -l)

if [ "$INFRA_RUNNING" -gt 0 ]; then
    echo -e "${GREEN}✓ Infrastructure already running (${INFRA_RUNNING} services)${NC}"
else
    echo -e "${YELLOW}ℹ Infrastructure not running. Starting...${NC}"
    docker compose -f docker-compose-infra.yml up -d --pull missing
    echo -e "${GREEN}✓ Infrastructure started${NC}"
    echo -e "${YELLOW}  Waiting 30 seconds for databases to initialize...${NC}"
    sleep 30
fi

if [ "$BACK_RUNNING" -gt 0 ]; then
    echo -e "${GREEN}✓ Backend services already running (${BACK_RUNNING} services)${NC}"
else
    echo -e "${YELLOW}ℹ Backend services not running. Starting...${NC}"
    docker compose -f docker-compose-back.yml -p zeferini-person-backend up -d --build
    echo -e "${GREEN}✓ Backend services started${NC}"
    echo -e "${YELLOW}  Waiting 20 seconds for APIs to initialize...${NC}"
    sleep 20
fi

# Step 3: Start load balancer
echo ""
echo -e "${YELLOW}[3/4] Starting load balancer...${NC}"

cd "$SCRIPT_DIR"

docker compose -f docker-compose-load-balancer.yml up -d --build
echo -e "${GREEN}✓ Load balancer started${NC}"

# Step 4: Verify health
echo ""
echo -e "${YELLOW}[4/4] Verifying health...${NC}"

sleep 5

LB_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8084/health 2>/dev/null || echo "000")
NESTJS_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health 2>/dev/null || echo "000")
DOTNET_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3002/health 2>/dev/null || echo "000")

echo ""
echo -e "Load Balancer (8084):  ${LB_HEALTH}"
echo -e "NestJS API (3000):     ${NESTJS_HEALTH}"
echo -e ".NET API (3002):       ${DOTNET_HEALTH}"

if [ "$LB_HEALTH" = "200" ]; then
    echo ""
    echo -e "${GREEN}✓ Load balancer is healthy!${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠ Load balancer health check returned ${LB_HEALTH}${NC}"
    echo "  Try: docker compose -f docker-compose-load-balancer.yml logs load-balancer"
fi

# Summary
echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Access points:"
echo "  Load Balancer:  http://localhost:8084"
echo "  Health Check:   http://localhost:8084/health"
echo "  Nginx Status:   http://localhost:8084/nginx_status"
echo ""
echo "Next steps:"
echo "  1. Test the load balancer: curl http://localhost:8084/api/persons"
echo "  2. Check logs: docker compose -f docker-compose-load-balancer.yml logs -f"
echo "  3. Run tests: ./test-endpoints.sh"
echo ""
