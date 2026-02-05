# Load Balancer Management Script for PowerShell
# Simplifica operações com docker-compose para o load balancer

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('up', 'down', 'logs', 'restart', 'status', 'health-check', 'shell')]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$Service = 'all',
    
    [Parameter(Mandatory=$false)]
    [switch]$BuildNow
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$composeFile = Join-Path $scriptDir "docker-compose-load-balancer.yml"

if (-not (Test-Path $composeFile)) {
    Write-Host "Error: $composeFile not found" -ForegroundColor Red
    exit 1
}

# Helper function to run docker-compose
function Invoke-Compose {
    param(
        [string[]]$Arguments
    )
    
    $args = @('-f', $composeFile) + $Arguments
    docker compose @args
}

# Helper function for colored output
function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )
    
    switch ($Type) {
        'Success' { Write-Host "✓ $Message" -ForegroundColor Green }
        'Error' { Write-Host "✗ $Message" -ForegroundColor Red }
        'Warning' { Write-Host "⚠ $Message" -ForegroundColor Yellow }
        default { Write-Host "ℹ $Message" -ForegroundColor Cyan }
    }
}

# Load .env file if exists
$envFile = Join-Path $scriptDir ".env"
if (Test-Path $envFile) {
    Write-Status "Loading .env file: $envFile"
}

# Execute action
switch ($Action) {
    'up' {
        Write-Status "Starting load balancer services..."
        if ($BuildNow) {
            Invoke-Compose 'up', '-d', '--build'
            Write-Status "Services built and started" Success
        } else {
            Invoke-Compose 'up', '-d'
            Write-Status "Services started" Success
        }
    }
    
    'down' {
        Write-Status "Stopping load balancer services..."
        Invoke-Compose 'down'
        Write-Status "Services stopped" Success
    }
    
    'logs' {
        $services = @('load-balancer', 'nestjs-app', 'dotnet-app', 'mysql-app', 'postgres-events', 'mongodb-query', 'rabbitmq')
        
        if ($Service -ne 'all') {
            $services = @($Service)
        }
        
        foreach ($svc in $services) {
            Write-Host "=== Logs for $svc ===" -ForegroundColor Cyan
            Invoke-Compose 'logs', '--tail=20', $svc
            Write-Host ""
        }
    }
    
    'restart' {
        Write-Status "Restarting services..."
        if ($Service -eq 'all') {
            Invoke-Compose 'restart'
        } else {
            Invoke-Compose 'restart', $Service
        }
        Write-Status "Services restarted" Success
    }
    
    'status' {
        Write-Status "Load Balancer Status"
        Write-Host ""
        Invoke-Compose 'ps'
    }
    
    'health-check' {
        Write-Status "Performing health checks..."
        Write-Host ""
        
        $endpoints = @(
            @{ Name = "Load Balancer"; Url = "http://localhost:8084/health" },
            @{ Name = "Nginx Status"; Url = "http://localhost:8084/nginx_status" },
            @{ Name = "Upstream Status"; Url = "http://localhost:8084/upstream_health" },
            @{ Name = "NestJS API"; Url = "http://localhost:3000/health" },
            @{ Name = ".NET API"; Url = "http://localhost:3002/health" }
        )
        
        foreach ($endpoint in $endpoints) {
            try {
                $response = Invoke-WebRequest -Uri $endpoint.Url -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
                if ($response.StatusCode -eq 200) {
                    Write-Status "$($endpoint.Name): OK (HTTP 200)" Success
                } else {
                    Write-Status "$($endpoint.Name): HTTP $($response.StatusCode)" Warning
                }
            } catch {
                Write-Status "$($endpoint.Name): UNREACHABLE" Error
            }
        }
        
        Write-Host ""
        Write-Status "Checking port connectivity..."
        
        $ports = @(
            @{ Name = "MySQL"; Host = "localhost"; Port = 3306 },
            @{ Name = "PostgreSQL"; Host = "localhost"; Port = 5433 },
            @{ Name = "MongoDB"; Host = "localhost"; Port = 27017 },
            @{ Name = "RabbitMQ"; Host = "localhost"; Port = 5672 }
        )
        
        foreach ($port in $ports) {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            try {
                $async = $tcpClient.BeginConnect($port.Host, $port.Port, $null, $null)
                $wait = $async.AsyncWaitHandle.WaitOne(2000, $false)
                
                if ($wait -and $tcpClient.Connected) {
                    Write-Status "$($port.Name) ($($port.Host):$($port.Port)): OPEN" Success
                } else {
                    Write-Status "$($port.Name) ($($port.Host):$($port.Port)): CLOSED" Error
                }
            } catch {
                Write-Status "$($port.Name): ERROR - $_" Error
            } finally {
                $tcpClient.Close()
            }
        }
    }
    
    'shell' {
        Write-Status "Opening shell in $Service container..."
        Invoke-Compose 'exec', $Service, 'sh'
    }
}

Write-Host ""
Write-Status "Operation complete"
