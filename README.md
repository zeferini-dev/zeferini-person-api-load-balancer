# API Load Balancer Configuration

Load balancer Nginx configurado para distribuir tráfego entre os serviços backend:
- **zeferini-person-api-nestjs** (porta 3000)
- **zeferini-person-api-dotnet** (porta 3002)

## Estrutura

```
zeferini-person-api-load-balancer/
├── Dockerfile                        # Imagem Nginx customizada
├── nginx.conf                        # Configuração do load balancer
├── docker-compose-load-balancer.yml  # Orquestração (APENAS load-balancer)
├── .env.example                      # Exemplo de variáveis
├── README.md                         # Este arquivo
├── DEPLOYMENT.md                     # Guia de deployment
├── health-check.sh                   # Script de health check
├── test-endpoints.sh                 # Script de teste de endpoints
└── lb-manage.ps1                     # Script PowerShell de gerenciamento
```

## Arquitetura Enxuta

Este docker-compose contém **APENAS o load-balancer Nginx**. Os demais serviços são providos por:

- **docker-compose-infra.yml**: Infraestrutura (PostgreSQL, MySQL, MongoDB, RabbitMQ, Kong, Keycloak, etc.)
- **docker-compose-back.yml**: Serviços backend (nestjs-app, dotnet-app, workers, consumers)
- **docker-compose-front.yml**: Serviços frontend (Angular, Vue, React, Spring, Blazor, Django)

## Configuração

### nginx.conf

Configuração Nginx com as seguintes features:

**Upstream (backend_servers)**
- Round-robin load balancing entre NestJS e .NET
- Weight: ambos com weight=1 (distribuição igual)

**Endpoints principais:**
- `/` - Load balancer principal (roundrobin entre backends)
- `/health` - Health check do load balancer
- `/nginx_status` - Status e métricas do Nginx
- `/api/persons` - Rota customizada de exemplo

**Características:**
- Proxy reverso com headers X-Forwarded-*
- Cache de arquivos estáticos
- Timeouts configuráveis
- Client max body size: 50MB

### docker-compose-load-balancer.yml

**Serviço único:**
1. **load-balancer** - Container Nginx com build local

**Redes (externas):**
- `zeferini-person-backend-backend-network` - Criada por docker-compose-back.yml

**Dependência:**
- Requer que nestjs-app e dotnet-app estejam rodando em docker-compose-back.yml

## Uso

### Pré-requisitos

1. **Infraestrutura já rodando** (em zeferini-teste-full-infra):
```bash
cd d:\GitHub\zeferini-dev\zeferini-dev\TesteFull\zeferini-teste-full-infra

# Terminal 1: Infraestrutura
docker compose -f docker-compose-infra.yml up -d

# Terminal 2: Backend
docker compose -f docker-compose-back.yml -p zeferini-person-backend up -d --build
```

2. **Arquivo `.env` configurado** com variáveis de ambiente

### Iniciar load balancer

```bash
cd D:\GitHub\zeferini-dev\zeferini-dev\TesteFull\zeferini-person-api-load-balancer

# Build e iniciar (recomendado na primeira vez)
docker compose -f docker-compose-load-balancer.yml up -d --build

# Se os prefixos do projeto forem diferentes, especificar:
docker compose -f docker-compose-load-balancer.yml -p zeferini-person-load-balancer up -d --build

# Apenas iniciar (se já tiver imagens)
docker compose -f docker-compose-load-balancer.yml up -d
```

### Parar load balancer

```bash
docker compose -f docker-compose-load-balancer.yml down

# Com limpeza de volumes (não afeta infra/back)
docker compose -f docker-compose-load-balancer.yml down -v
```

## Acessos

| Serviço | URL | Descrição |
|---------|-----|-----------|
| Load Balancer | http://localhost:8084 | Ponto de entrada (roundrobin) |
| Health Check | http://localhost:8084/health | Status do LB |
| Nginx Status | http://localhost:8084/nginx_status | Métricas do Nginx |

**Backends (diretos, sem load balancer):**
- NestJS: http://localhost:3000
- .NET: http://localhost:3002

**Infraestrutura (gerenciamento):**
- Kong Admin: http://localhost:8001
- Kong Admin GUI: http://localhost:8002
- Keycloak: http://localhost:8082
- Nginx Proxy Manager: http://localhost:81
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3100

## Algoritmo de Load Balancing

**Round-Robin** com pesos iguais entre NestJS e .NET

## Troubleshooting

```bash
# Verificar logs
docker compose -f docker-compose-load-balancer.yml logs load-balancer

# Verificar configuração Nginx
docker compose -f docker-compose-load-balancer.yml exec load-balancer nginx -t

# Limpar e recriar
docker compose -f docker-compose-load-balancer.yml down -v
docker compose -f docker-compose-load-balancer.yml up -d --build
```
