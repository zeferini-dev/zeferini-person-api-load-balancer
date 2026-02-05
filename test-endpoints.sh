#!/bin/bash

# Load Balancer Testing Script
# Testa todos os endpoints do load balancer

set -e

# Colors for output
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
LB_URL="http://localhost:8084"
NESTJS_URL="http://localhost:3000"
DOTNET_URL="http://localhost:3002"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to test endpoint
test_endpoint() {
    local name=$1
    local method=$2
    local url=$3
    local expected_code=$4
    local data=$5
    
    echo -n "Testing $name ... "
    
    if [ -z "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" 2>/dev/null || echo "000")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" -H "Content-Type: application/json" -d "$data" 2>/dev/null || echo "000")
    fi
    
    http_code=$(echo "$response" | tail -n 1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "$expected_code" ]; then
        echo -e "${GREEN}PASS${NC} ($http_code)"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC} (got $http_code, expected $expected_code)"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to test upstream health
test_upstream_health() {
    local name=$1
    local url=$2
    
    echo -n "Testing upstream health ... "
    
    response=$(curl -s "$url" 2>/dev/null)
    
    if echo "$response" | grep -q '"status"'; then
        echo -e "${GREEN}PASS${NC}"
        echo -e "  Response: $response"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo -e "  Response: $response"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}Load Balancer API Tests${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""

# Load Balancer Tests
echo -e "${BOLD}1. Load Balancer Tests${NC}"
test_endpoint "Load Balancer Health" "GET" "$LB_URL/health" "200"
test_endpoint "Nginx Status" "GET" "$LB_URL/nginx_status" "200"
test_upstream_health "Upstream Health Status" "$LB_URL/upstream_health"

echo ""
echo -e "${BOLD}2. Proxy Tests (through load balancer)${NC}"
test_endpoint "GET / (via LB)" "GET" "$LB_URL/api/persons" "200"
test_endpoint "GET /health (via LB)" "GET" "$LB_URL/health" "200"

echo ""
echo -e "${BOLD}3. Direct Backend Tests${NC}"
test_endpoint "NestJS Health" "GET" "$NESTJS_URL/health" "200"
test_endpoint ".NET Health" "GET" "$DOTNET_URL/health" "200" || true

echo ""
echo -e "${BOLD}4. POST Request Tests${NC}"
test_endpoint "POST JSON" "POST" "$LB_URL/api/persons" "400" '{"name":"test"}' || true

echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}Test Summary${NC}"
echo -e "${BOLD}========================================${NC}"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
