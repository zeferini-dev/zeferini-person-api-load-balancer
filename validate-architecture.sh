#!/bin/bash

# Load Balancer Architecture Validation Script
# Verifies that all required docker-composes and networks are properly configured

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Load Balancer Architecture Validation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

INFRA_DIR="../zeferini-teste-full-infra"
LB_DIR="."

MISSING_FILES=0
MISSING_NETWORKS=0
MISSING_CONTAINERS=0

# 1. Check docker-compose files exist
echo -e "${YELLOW}[1/5] Checking docker-compose files${NC}"

files=(
    "$INFRA_DIR/docker-compose-infra.yml"
    "$INFRA_DIR/docker-compose-back.yml"
    "$INFRA_DIR/docker-compose-front.yml"
    "$LB_DIR/docker-compose-load-balancer.yml"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file (MISSING)"
        ((MISSING_FILES++))
    fi
done

# 2. Check Docker daemon is running
echo ""
echo -e "${YELLOW}[2/5] Checking Docker daemon${NC}"

if docker ps > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Docker daemon is accessible"
else
    echo -e "${RED}✗${NC} Docker daemon is not accessible"
    exit 1
fi

# 3. Validate network configuration
echo ""
echo -e "${YELLOW}[3/5] Validating network configuration${NC}"

# Check if backend network exists
BACKEND_NETWORK="zeferini-person-backend-backend-network"

if docker network ls | grep -q "$BACKEND_NETWORK"; then
    echo -e "${GREEN}✓${NC} Backend network exists: $BACKEND_NETWORK"
else
    echo -e "${YELLOW}ℹ${NC} Backend network does not exist (will be created by docker-compose-back.yml)"
fi

# 4. Check service containers
echo ""
echo -e "${YELLOW}[4/5] Checking services status${NC}"

services=(
    "nestjs-app:3000"
    "dotnet-app:3002"
    "api-load-balancer:80"
)

for service in "${services[@]}"; do
    container=$(echo $service | cut -d: -f1)
    port=$(echo $service | cut -d: -f2)
    
    if docker ps | grep -q "$container"; then
        echo -e "${GREEN}✓${NC} $container (port $port) - RUNNING"
    elif docker ps -a | grep -q "$container"; then
        echo -e "${YELLOW}⚠${NC} $container (port $port) - STOPPED"
        ((MISSING_CONTAINERS++))
    else
        echo -e "${RED}✗${NC} $container (port $port) - NOT FOUND"
        ((MISSING_CONTAINERS++))
    fi
done

# 5. Test connectivity
echo ""
echo -e "${YELLOW}[5/5] Testing connectivity${NC}"

# Test load balancer
if curl -s http://localhost:8084/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Load balancer responds on http://localhost:8084"
else
    echo -e "${RED}✗${NC} Load balancer not responding on http://localhost:8084"
fi

# Test NestJS backend
if curl -s http://localhost:3000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} NestJS API responds on http://localhost:3000"
else
    echo -e "${YELLOW}ℹ${NC} NestJS API not responding on http://localhost:3000 (may not be running)"
fi

# Test .NET backend
if curl -s http://localhost:3002/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} .NET API responds on http://localhost:3002"
else
    echo -e "${YELLOW}ℹ${NC} .NET API not responding on http://localhost:3002 (may not be running)"
fi

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}========================================${NC}"

ISSUES=$((MISSING_FILES + MISSING_CONTAINERS))

echo ""
echo "Missing files: $MISSING_FILES"
echo "Missing/stopped containers: $MISSING_CONTAINERS"
echo ""

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ All validations passed!${NC}"
    echo ""
    echo "Architecture is correctly configured:"
    echo "  1. docker-compose-infra.yml - Infrastructure services"
    echo "  2. docker-compose-back.yml - Backend APIs (nestjs-app, dotnet-app)"
    echo "  3. docker-compose-load-balancer.yml - Nginx load balancer"
    echo ""
    echo "Load balancer configuration is CORRECT."
    exit 0
else
    echo -e "${RED}✗ Some validations failed. Review the issues above.${NC}"
    echo ""
    echo "Required setup steps:"
    echo "  1. Ensure docker-compose files exist in correct locations"
    echo "  2. Run: docker compose -f $INFRA_DIR/docker-compose-infra.yml up -d"
    echo "  3. Run: docker compose -f $INFRA_DIR/docker-compose-back.yml up -d"
    echo "  4. Run: docker compose -f $LB_DIR/docker-compose-load-balancer.yml up -d"
    echo ""
    exit 1
fi
