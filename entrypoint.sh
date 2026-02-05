#!/bin/sh

# Wait for backend services to be available
echo "Waiting for backend services..."

# Function to check if a host:port is reachable
wait_for_service() {
    local host=$1
    local port=$2
    local count=0
    
    echo "Checking if $host:$port is available..."
    
    while ! nc -z $host $port 2>/dev/null; do
        count=$((count + 1))
        if [ $count -gt 60 ]; then
            echo "ERROR: Service $host:$port did not become available after 60 attempts"
            exit 1
        fi
        echo "Waiting for $host:$port... (attempt $count/60)"
        sleep 1
    done
    
    echo "✓ Service $host:$port is available"
}

# Wait for both backend services
wait_for_service nestjs-app 3000
wait_for_service dotnet-app 3002

echo "All backend services are available!"

# Start nginx
echo "Starting nginx..."
exec nginx -g "daemon off;"
