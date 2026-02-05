#!/bin/bash

# Health Check Script for Load Balancer
# Monitora a saúde dos serviços do load balancer

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
LB_URL="http://localhost:8084"
NESTJS_URL="http://localhost:3000"
DOTNET_URL="http://localhost:3002"
MYSQL_HOST="localhost"
MYSQL_PORT=3306
POSTGRES_HOST="localhost"
POSTGRES_PORT=5433
MONGO_HOST="localhost"
MONGO_PORT=27017
RABBITMQ_HOST="localhost"
RABBITMQ_PORT=5672

# Function to print status
check_status() {
    local service=$1
    local url=$2
    local status=$(curl -s -f -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$status" = "200" ] || [ "$status" = "404" ]; then
        echo -e "${GREEN}✓${NC} $service: UP (HTTP $status)"
        return 0
    else
        echo -e "${RED}✗${NC} $service: DOWN (HTTP $status)"
        return 1
    fi
}

# Function to check port
check_port() {
    local service=$1
    local host=$2
    local port=$3
    
    if timeout 2 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $service: PORT OPEN ($host:$port)"
        return 0
    else
        echo -e "${RED}✗${NC} $service: PORT CLOSED ($host:$port)"
        return 1
    fi
}

echo "=========================================="
echo "Load Balancer Health Check"
echo "=========================================="
echo ""

# Check HTTP services
echo "HTTP Services:"
check_status "Load Balancer" "$LB_URL/health" || true
check_status "NestJS API" "$NESTJS_URL/health" || true
check_status "Nginx Status" "$LB_URL/nginx_status" || true
check_status "Upstream Status" "$LB_URL/upstream_health" || true

echo ""
echo "Backend Services:"
check_status "NestJS Backend" "$NESTJS_URL" || true
check_status ".NET Backend" "$DOTNET_URL" || true

echo ""
echo "Database Connections:"
check_port "MySQL" "$MYSQL_HOST" "$MYSQL_PORT" || true
check_port "PostgreSQL" "$POSTGRES_HOST" "$POSTGRES_PORT" || true
check_port "MongoDB" "$MONGO_HOST" "$MONGO_PORT" || true

echo ""
echo "Message Broker:"
check_port "RabbitMQ" "$RABBITMQ_HOST" "$RABBITMQ_PORT" || true

echo ""
echo "=========================================="
echo "Health Check Complete"
echo "=========================================="
