# Deployment Guide - Load Balancer

Guia para deploy do load balancer Nginx como camada de roteamento entre zeferini-person-api-nestjs e zeferini-person-api-dotnet.

## Arquitetura

Este deployment é **enxuto e complementar** - contém apenas o load balancer Nginx. A infraestrutura completa é composta por 3 docker-composes independentes:

```
zeferini-teste-full-infra/
├── docker-compose-infra.yml       ← Infraestrutura (DB, MQ, etc)
├── docker-compose-back.yml        ← Backend APIs (NestJS, .NET)
└── docker-compose-front.yml       ← Frontend (Angular, Vue, React, etc)

zeferini-person-api-load-balancer/
└── docker-compose-load-balancer.yml  ← APENAS Load Balancer (Nginx)
```
2. [Estrutura do Projeto](#estrutura-do-projeto)
3. [Configuração Inicial](#configuração-inicial)
4. [Deploy Passo a Passo](#deploy-passo-a-passo)
5. [Verificação de Saúde](#verificação-de-saúde)
6. [Troubleshooting](#troubleshooting)
7. [Monitoramento](#monitoramento)

## Índice

1. [Arquitetura](#arquitetura)
2. [Pré-requisitos](#pré-requisitos)
3. [Sequência de Startup](#sequência-de-startup)
4. [Verificação de Saúde](#verificação-de-saúde)
5. [Troubleshooting](#troubleshooting)
6. [Monitoramento](#monitoramento)

## Pré-requisitos

### Software Necessário

- **Docker**: v20.10+
- **Docker Compose**: v2.0+
- **Git**: Qualquer versão recente
- **PowerShell**: 5.0+ (para scripts de gerenciamento)

### Recursos do Sistema

- **CPU**: Mínimo 4 cores
- **RAM**: Mínimo 8GB (para rodar infra + back + load-balancer)
- **Disco**: Mínimo 20GB livre

### Serviços Já Rodando

Este load-balancer **depende** dos seguintes docker-composes já estarem ativos:

1. **docker-compose-infra.yml** (zeferini-teste-full-infra)
   - PostgreSQL (5432, 5433)
   - MySQL (3306)
   - MongoDB (27017)
   - RabbitMQ (5672)
   - Kong, Keycloak, Prometheus, Grafana, etc.

2. **docker-compose-back.yml** (zeferini-teste-full-infra)
   - nestjs-app (3000)
   - dotnet-app (3002)
   - event-worker, mysql-consumer, mongo-sync
   - api-gateway (8084)

## Sequência de Startup

### Ordem Recomendada

```bash
# 1. Terminal 1 - Infraestrutura base (executar UMA VEZ)
cd d:\GitHub\zeferini-dev\zeferini-dev\TesteFull\zeferini-teste-full-infra
docker compose -f docker-compose-infra.yml up -d

# Aguardar ~30 segundos para databases ficarem healthy

# 2. Terminal 2 - Backend API
docker compose -f docker-compose-back.yml -p zeferini-person-backend up -d --build

# Aguardar ~20 segundos para APIs ficarem prontas

# 3. Terminal 3 - Load Balancer (NESTE DIRETÓRIO)
cd ..\zeferini-person-api-load-balancer
docker compose -f docker-compose-load-balancer.yml up -d --build

# 4. Opcional - Frontend
# cd ..\zeferini-teste-full-infra
# docker compose -f docker-compose-front.yml -p zeferini-person-frontend up -d --build
```

### Verificar Network Criada

```bash
# docker-compose-back.yml CRIA a network
docker network ls | grep zeferini-person-backend-backend-network

# docker-compose-load-balancer.yml ACESSA essa network (external)
docker network inspect zeferini-person-backend-backend-network
```

## Estrutura do Projeto

```
zeferini-person-api-load-balancer/
├── Dockerfile                        # Imagem Nginx alpine
├── nginx.conf                        # Configuração Nginx
├── docker-compose-load-balancer.yml  # APENAS load-balancer
├── .env.example                      # Exemplo de variáveis
├── README.md                         # Documentação principal
├── DEPLOYMENT.md                     # Este arquivo
├── health-check.sh                   # Script de health check
├── test-endpoints.sh                 # Script de teste
└── lb-manage.ps1                     # Script PowerShell
```

## Configuração Inicial

### 1. Arquivo .env (opcional)

```bash
# Copiar se precisar customizar
cp .env.example .env

# Editar se precisar alterar porta ou variáveis
notepad .env
```

**Variáveis importantes:**
- `LB_PORT=8084` - Porta do load balancer (padrão)
- Demais variáveis são ignoradas (infra está em outro docker-compose)

## Deploy Passo a Passo

### Método 1: PowerShell (Recomendado para Windows)

```powershell
# 1. Iniciar o load balancer
.\lb-manage.ps1 -Action up -BuildNow

# 2. Verificar status
.\lb-manage.ps1 -Action status

# 3. Ver logs
.\lb-manage.ps1 -Action logs

# 4. Executar health check
.\lb-manage.ps1 -Action health-check

# 5. Acessar shell do container
.\lb-manage.ps1 -Action shell -Service load-balancer
```

### Método 2: Docker Compose Direto

```bash
# 1. Build e iniciar (recomendado na primeira vez)
docker compose -f docker-compose-load-balancer.yml up -d --build

# 2. Ver status dos containers
docker compose -f docker-compose-load-balancer.yml ps

# 3. Ver logs em tempo real
docker compose -f docker-compose-load-balancer.yml logs -f

# 4. Parar todos os serviços
docker compose -f docker-compose-load-balancer.yml down

# 5. Parar e remover volumes
docker compose -f docker-compose-load-balancer.yml down -v
```

### Método 3: Script Bash

```bash
# 1. Executar health check
bash health-check.sh

# 2. Testar endpoints
bash test-endpoints.sh
```

## Verificação de Saúde

### Health Check Automático

```bash
# Verificar saúde de todos os serviços
bash health-check.sh
```

Saída esperada:
```
✓ Load Balancer: UP (HTTP 200)
✓ NestJS API: UP (HTTP 200)
✓ .NET API: UP (HTTP 200)
✓ MySQL: PORT OPEN (localhost:3306)
✓ PostgreSQL: PORT OPEN (localhost:5433)
✓ MongoDB: PORT OPEN (localhost:27017)
✓ RabbitMQ: PORT OPEN (localhost:5672)
```

### Testes de Endpoint

```bash
# Executar suite de testes
bash test-endpoints.sh
```

### Verificações Manuais

#### Load Balancer
```bash
# Health check
curl -i http://localhost:8084/health
# Esperado: HTTP/1.1 200 OK

# Status do Nginx
curl http://localhost:8084/nginx_status

# Status dos upstreams
curl http://localhost:8084/upstream_health
```

#### Backend NestJS
```bash
curl -i http://localhost:3000/health
# Esperado: HTTP/1.1 200 OK
```

#### Backend .NET
```bash
curl -i http://localhost:3002/health
# Esperado: HTTP/1.1 200 OK
```

## Troubleshooting

### Container não inicia

```bash
# Ver logs detalhados
docker compose -f docker-compose-load-balancer.yml logs load-balancer

# Testar configuração Nginx
docker compose -f docker-compose-load-balancer.yml exec load-balancer nginx -t

# Limpar e reconstruir
docker compose -f docker-compose-load-balancer.yml down -v
docker system prune -a
docker compose -f docker-compose-load-balancer.yml up -d --build
```

### Port já em uso

```bash
# Encontrar processo usando a porta 8084
netstat -ano | findstr :8084

# Matar processo (PowerShell admin)
Stop-Process -Id PID -Force

# Ou, usar porta diferente
# Editar .env e mudar LB_PORT=8085
docker compose -f docker-compose-load-balancer.yml up -d --build
```

### Erro de conexão MySQL

```bash
# Verificar logs do MySQL
docker compose -f docker-compose-load-balancer.yml logs mysql-app

# Testar conectividade
docker compose -f docker-compose-load-balancer.yml exec mysql-app \
  mysql -u root -proot123 -e "SHOW DATABASES;"
```

### Upstreams desconectados

```bash
# Verificar status dos upstreams
curl http://localhost:8084/upstream_health

# Reiniciar backends
docker compose -f docker-compose-load-balancer.yml restart nestjs-app
docker compose -f docker-compose-load-balancer.yml restart dotnet-app

# Aguardar estabilização (30 segundos)
# Verificar novamente
curl http://localhost:8084/upstream_health
```

### Erro de DNS (não consegue resolver nestjs-app)

```bash
# Verificar network Docker
docker network ls

# Inspecionar network do compose
docker network inspect zeferini_default

# Reiniciar compose
docker compose -f docker-compose-load-balancer.yml restart
```

## Monitoramento

### Logs em Tempo Real

```bash
# Todos os serviços
docker compose -f docker-compose-load-balancer.yml logs -f

# Apenas load-balancer
docker compose -f docker-compose-load-balancer.yml logs -f load-balancer

# Últimas 50 linhas, seguir
docker compose -f docker-compose-load-balancer.yml logs -f --tail=50
```

### Métricas Nginx

```bash
# Acessar status do Nginx
curl http://localhost:8084/nginx_status

# Output esperado:
# Active connections: 1
# server accepts handled requests
#  15 15 15
# Reading: 0 Writing: 1 Waiting: 0
```

### Distribuição de Carga

```bash
# Fazer múltiplas requisições e verificar distribuição
for i in {1..10}; do
  curl -i http://localhost:8084/api/persons | grep -i "x-served-by"
done
```

### Performance

```bash
# Apache Bench (ab disponível com Apache Tools)
ab -n 1000 -c 10 http://localhost:8084/api/persons

# Wrk (benchmark tool)
# wrk -t4 -c100 -d30s http://localhost:8084/api/persons
```

### Container Stats

```bash
# Ver uso de recursos em tempo real
docker stats --no-stream

# Específico por container
docker stats load-balancer
docker stats nestjs-app
docker stats dotnet-app
```

## Checklist Pré-Deploy

- [ ] Docker instalado e rodando
- [ ] Arquivo `.env` criado e configurado
- [ ] Portas 8084, 3000, 3002, 3306, 5433, 27017, 5672 livres
- [ ] Espaco em disco disponível (10GB+)
- [ ] Imagens base disponíveis:
  - [ ] nginx:1.25-alpine
  - [ ] node:20-alpine
  - [ ] mcr.microsoft.com/dotnet/aspnet:10.0
  - [ ] postgres:16-alpine
  - [ ] mysql:8.0
  - [ ] mongo:7
  - [ ] rabbitmq:3-management-alpine

## Checklist Pós-Deploy

- [ ] Todos os containers em estado "running"
- [ ] `curl http://localhost:8084/health` retorna 200
- [ ] `curl http://localhost:8084/upstream_health` mostra upstreams UP
- [ ] Logs sem erros críticos
- [ ] Performance dentro do esperado
- [ ] Conectividade com bancos de dados confirmada

## Rollback

Se houver problemas após deploy:

```bash
# Parar tudo e remover
docker compose -f docker-compose-load-balancer.yml down -v

# Limpar images
docker rmi zeferini-person-load-balancer:latest

# Redeploy com version anterior
git checkout HEAD~1 docker-compose-load-balancer.yml
docker compose -f docker-compose-load-balancer.yml up -d --build
```

## Suporte

Para problemas, consulte:
1. [README.md](/README.md) - Documentação geral
2. [Logs Docker](#logs-em-tempo-real)
3. [Health Check Status](#health-check-automático)
4. Scripts de teste em `test-endpoints.sh`
