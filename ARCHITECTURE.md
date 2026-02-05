# Load Balancer Architecture - Complete Reference

## Visão Geral

O sistema completo de deploymentdo Zeferini é composto por **3 docker-composes independentes**:

```
zeferini-teste-full-infra/
├── docker-compose-infra.yml        ← Infraestrutura (base)
├── docker-compose-back.yml         ← APIs backend
└── docker-compose-front.yml        ← Frontends

zeferini-person-api-load-balancer/
└── docker-compose-load-balancer.yml  ← Load balancer (depende dos anteriores)
```

## 1. docker-compose-infra.yml
**Localização:** `zeferini-teste-full-infra/`  
**Responsabilidade:** Infraestrutura compartilhada  
**Rede:** `infra-network`  
**Serviços:**
- PostgreSQL (keycloak + events)
- MySQL
- MongoDB
- RabbitMQ
- Kong + Kong Database
- Keycloak
- Nginx Proxy Manager
- Prometheus + Grafana + Loki
- Node Exporter, cAdvisor, Promtail
- Nexus Repository
- Weave Scope
- DuckDNS

## 2. docker-compose-back.yml
**Localização:** `zeferini-teste-full-infra/`  
**Responsabilidade:** Serviços backend (APIs)  
**Redes:** 
- `backend-network` (criada/gerenciada aqui)
- `infra-network` (conecta à infraestrutura)

**Serviços:**
- event-worker
- mysql-consumer
- mongo-sync
- **nestjs-app** (port 3000) ← **Load balancer roteia para aqui**
- **dotnet-app** (port 3002) ← **Load balancer roteia para aqui**
- api-gateway (port 8084)

## 3. docker-compose-front.yml
**Localização:** `zeferini-teste-full-infra/`  
**Responsabilidade:** Frontends  
**Redes:**
- `frontend-network` (própria)
- `backend-network` (acessa APIs)
- `infra-network` (Keycloak, etc)

**Serviços:**
- Angular
- Vue
- React
- Spring
- Blazor
- Django

## 4. docker-compose-load-balancer.yml ⭐
**Localização:** `zeferini-person-api-load-balancer/`  
**Responsabilidade:** Load balancing entre APIs  
**Rede:**
- `zeferini-person-backend-backend-network` (externa, criada por docker-compose-back.yml)

**Serviços:**
- **load-balancer** (port 8084 localhost)

## Fluxo de Tráfego

```
Internet/Client
    ↓
Nginx Load Balancer (http://localhost:8084)
    ↙              ↖
Round-robin distribution
    ↙              ↖
nestjs-app     dotnet-app
(port 3000)    (port 3002)
    ↓              ↓
    └──────┬───────┘
           ↓
   Backend Infra Network
   (MySQL, PostgreSQL, MongoDB, RabbitMQ)
```

## Componentes de Rede

### 1. infra-network (docker-compose-infra.yml)
- **Driver:** bridge
- **Escopo:** Dados e serviços de infraestrutura
- **Serviços:** PostgreSQL, MySQL, MongoDB, RabbitMQ, Kong, Keycloak, etc
- **Acesso:** Services que precisam de BD e MQ

### 2. backend-network (docker-compose-back.yml)
- **Driver:** bridge
- **Escopo:** APIs e workers backend
- **Serviços:** nestjs-app, dotnet-app, event-worker, mysql-consumer
- **Acesso:** O **load-balancer acessa externalmente**

### 3. frontend-network (docker-compose-front.yml)
- **Driver:** bridge
- **Escopo:** Aplicações frontend
- **Serviços:** Angular, Vue, React, Spring, Blazor, Django
- **Acesso:** Não conectado ao load-balancer

## Configuração do Load Balancer

### docker-compose-load-balancer.yml
```yaml
services:
  load-balancer:
    networks:
      - zeferini-backend-network  # External!
    ports:
      - "127.0.0.1:8084:80"       # Porta local
```

### nginx.conf
```nginx
upstream backend_servers {
    server nestjs-app:3000 weight=1;
    server dotnet-app:3002 weight=1;
}

server {
    listen 80;
    location / {
        proxy_pass http://backend_servers;
        # Headers forwarding...
    }
}
```

**Nota:** Os nomes `nestjs-app` e `dotnet-app` são resolvidos via Docker DNS porque estão na mesma network (`zeferini-person-backend-backend-network`).

## Sequência de Deploy

### Pré-requisitos
1. Docker Desktop rodando
2. `.env` configurado (em zeferini-teste-full-infra)

### Passo 1: Infraestrutura
```bash
cd zeferini-teste-full-infra
docker compose -f docker-compose-infra.yml up -d
# Aguardar ~30 segundos
```

### Passo 2: Backend APIs
```bash
docker compose -f docker-compose-back.yml -p zeferini-person-backend up -d --build
# Aguardar ~20 segundos
```

### Passo 3: Load Balancer
```bash
cd ../zeferini-person-api-load-balancer
docker compose -f docker-compose-load-balancer.yml up -d --build
```

### Verificação
```bash
# Testar load balancer
curl http://localhost:8084/health           # Deve retornar 200
curl http://localhost:8084/nginx_status     # Métricas Nginx

# Testar roundrobin (vai alternar entre NestJS e .NET)
for i in {1..4}; do
  curl http://localhost:8084/api/persons -i | grep -i "server"
done
```

## Vantagens da Arquitetura Enxuta

✅ **Separação de Responsabilidades:**
- Infra em um compose
- APIs em outro compose
- Load balancer em outro compose
- Cada um pode ser updatizado independentemente

✅ **Escalabilidade:**
- Adicionar nestjs-app2, dotnet-app2 sem modificar load-balancer
- Apenas atualizar upstream no nginx.conf

✅ **Manutenibilidade:**
- Cada compose é pequeno e focado
- Fácil debugar problemas de rede
- Reusar infraestrutura para outros projetos

✅ **Performance:**
- Nginx é leve
- Round-robin nativo (zero overhead)
- Sem duplicação de serviços

## Troubleshooting Comum

### Load balancer não acessa nestjs-app
```bash
# Verificar se rede existe
docker network ls | grep zeferini-person-backend-backend-network

# Verificar se nestjs-app está na rede
docker network inspect zeferini-person-backend-backend-network | grep nestjs-app

# Testar DNS resolution
docker exec api-load-balancer nslookup nestjs-app
```

### Erro "zeferini-person-backend-backend-network not found"
```bash
# SOLUÇÃO: docker-compose-back.yml não foi executado ainda
cd zeferini-teste-full-infra
docker compose -f docker-compose-back.yml -p zeferini-person-backend up -d --build
```

### Load balancer está up mas não roteia para backends
```bash
# Ver logs do nginx
docker compose -f docker-compose-load-balancer.yml logs load-balancer

# Verificar se backends estão saudáveis
curl http://localhost:3000/health
curl http://localhost:3002/health
```

## Endponts do Load Balancer

| Endpoint | Descrição |
|----------|-----------|
| `http://localhost:8084` | Roundrobin para nestjs-app:3000 ou dotnet-app:3002 |
| `http://localhost:8084/health` | Health check |
| `http://localhost:8084/nginx_status` | Métricas Nginx |
| `http://localhost:8084/api/*` | Proxied para backends |

## Componentes Fornecidos

### Scripts
- `quickstart.sh` / `quickstart.ps1` - Startup automático
- `health-check.sh` - Verifica saúde de todos os serviços
- `test-endpoints.sh` - Testa endpoints do load balancer
- `validate-architecture.sh` - Valida compatibilidade
- `lb-manage.ps1` - Management PowerShell

### Documentação
- `README.md` - Visão geral e uso básico
- `DEPLOYMENT.md` - Guia completo de deployment
- `ARCHITECTURE.md` - Este arquivo (referência técnica)

## Variáveis de Ambiente

O `.env` é COMPARTILHADO entre os 3 docker-composes (todos em zeferini-teste-full-infra).

Load balancer ignora a maioria das variáveis (usa a network external).

**Única variável relevante:**
- `LB_PORT=8084` - Porta do load balancer (padrão)
