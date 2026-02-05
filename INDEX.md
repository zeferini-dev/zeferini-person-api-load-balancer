# 📚 Load Balancer - Índice de Documentação

Bem-vindo à documentação do Load Balancer Nginx otimizado para Zeferini.

## 🚀 Comece Aqui

### Para Iniciar Rápido (5 minutos)
1. Leia [OPTIMIZATION_SUMMARY.md](OPTIMIZATION_SUMMARY.md) - Resume as mudanças
2. Execute `quickstart.ps1` ou `quickstart.sh`
3. Teste em http://localhost:8084/health

### Para Entender a Arquitetura
1. Leia [README.md](README.md) - Visão geral
2. Leia [ARCHITECTURE.md](ARCHITECTURE.md) - Detalhes técnicos
3. Execute `validate-architecture.sh` - Validar setup

### Para Fazer Deploy em Produção
1. Leia [DEPLOYMENT.md](DEPLOYMENT.md) - Guia completo
2. Configure `.env` com suas variáveis
3. Siga a sequência de startup
4. Execute testes de health

### Para Solucionar Problemas
1. Execute `bash validate-architecture.sh` - Diagnóstico
2. Consulte [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Soluções comuns
3. Verifique logs: `docker compose -f docker-compose-load-balancer.yml logs -f`

---

## 📖 Documentação Detalhada

### [README.md](README.md)
**O que é:** Overview e guia de uso básico  
**Para quem:** Todos os usuários  
**Tempo:** 5 minutos  
**Conteúdo:**
- Estrutura do projeto
- Configuração básica
- Uso do load balancer
- Endpoints disponíveis
- Algoritmo de balanceamento

---

### [OPTIMIZATION_SUMMARY.md](OPTIMIZATION_SUMMARY.md) ⭐
**O que é:** Resumo das otimizações realizadas  
**Para quem:** Quem quer entender o que mudou  
**Tempo:** 3 minutos  
**Conteúdo:**
- Comparação antes/depois
- Estatísticas de melhoria
- Arquitetura resultante
- Como usar a versão nova
- Validação

---

### [ARCHITECTURE.md](ARCHITECTURE.md)
**O que é:** Referência técnica completa  
**Para quem:** Arquitetos, DevOps, desenvolvedores avançados  
**Tempo:** 15 minutos  
**Conteúdo:**
- Visão geral do sistema (3 docker-composes)
- Descrição de cada compose
- Fluxo de tráfego
- Componentes de rede
- Configuração de load balancer
- Sequência de deploy
- Troubleshooting técnico
- Endponts e variáveis

---

### [DEPLOYMENT.md](DEPLOYMENT.md)
**O que é:** Guia passo-a-passo para deploy  
**Para quem:** DevOps, SREs, operadores  
**Tempo:** 30 minutos (leitura + setup)  
**Conteúdo:**
- Pré-requisitos detalhados
- Sequência de startup exata
- Verificação de saúde
- Troubleshooting de deploy
- Monitoramento
- Checklist pré/pós-deploy
- Rollback

---

### [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
**O que é:** Cheat sheet e troubleshooting  
**Para quem:** Quem precisa de respostas rápidas  
**Tempo:** 1 minuto (busca por problema)  
**Conteúdo:**
- Comandos mais usados
- Dicas de diagnóstico
- 10+ problemas comuns com soluções
- Restart scenarios
- Monitoramento
- Mudanças de configuração
- Checklist de validação

---

## 🛠️ Scripts Fornecidos

### [quickstart.sh](quickstart.sh)
**Plataforma:** Linux / macOS  
**Função:** Startup automático com validações  
**Uso:**
```bash
bash quickstart.sh
# ✓ Verifica pré-requisitos
# ✓ Inicia infra+back+load-balancer
# ✓ Aguarda inicialização
# ✓ Valida saúde
```

---

### [quickstart.ps1](quickstart.ps1)
**Plataforma:** Windows PowerShell  
**Função:** Startup automático com validações  
**Uso:**
```powershell
.\quickstart.ps1
# Ou com opções
.\quickstart.ps1 -SkipInfra -SkipWait
```

---

### [validate-architecture.sh](validate-architecture.sh)
**Função:** Valida que tudo está configurado corretamente  
**Uso:**
```bash
bash validate-architecture.sh
# ✓ Verifica arquivos docker-compose
# ✓ Valida Docker daemon
# ✓ Verifica redes
# ✓ Testa conectividade
```

---

### [health-check.sh](health-check.sh)
**Função:** Verifica saúde de todos os serviços  
**Uso:**
```bash
bash health-check.sh
# ✓ Load balancer
# ✓ NestJS API
# ✓ .NET API
# ✓ Bancos de dados
# ✓ Message broker
```

---

### [test-endpoints.sh](test-endpoints.sh)
**Função:** Testa endpoints HTTP do load balancer  
**Uso:**
```bash
bash test-endpoints.sh
# ✓ Testa health checks
# ✓ Testa proxy
# ✓ Testa POST requests
# ✓ Resumo de testes
```

---

### [lb-manage.ps1](lb-manage.ps1)
**Função:** Management tool Windows PowerShell  
**Uso:**
```powershell
.\lb-manage.ps1 -Action up -BuildNow
.\lb-manage.ps1 -Action logs
.\lb-manage.ps1 -Action health-check
.\lb-manage.ps1 -Action shell -Service load-balancer
```

---

## 📋 Arquivos de Configuração

### [docker-compose-load-balancer.yml](docker-compose-load-balancer.yml)
**O que é:** Orchestração Docker do load balancer  
**Tamanho:** 60 linhas (otimizado)  
**Conteúdo:**
- 1 serviço (load-balancer)
- 1 rede externa (zeferini-person-backend-backend-network)
- Health checks configurados

### [nginx.conf](nginx.conf)
**O que é:** Configuração do Nginx  
**Módulos:** Apenas módulos padrão  
**Conteúdo:**
- Upstream com 2 backends (roundrobin)
- 4 endpoints principais
- Headers de proxy
- Cache de assets estáticos

### [.env.example](.env.example)
**O que é:** Template de variáveis de ambiente  
**Uso:** `cp .env.example .env && edit .env`
**Variáveis principais:**
- LB_PORT=8084 (única relevante para load-balancer)

### [Dockerfile](Dockerfile)
**O que é:** Imagem do load balancer  
**Base:** nginx:1.25-alpine (leve e segura)  
**Customizações:**
- Cópia de nginx.conf
- Health check

---

## 🔄 Fluxo de Uso Recomendado

```
┌─────────────────────────────────────┐
│  1. Leia OPTIMIZATION_SUMMARY.md    │ (5 min)
│     (entender o que mudou)          │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│  2. Leia README.md                  │ (5 min)
│     (visão geral)                   │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│  3. Escolha caminho:                │
│  A) Começar rápido:                 │
│     .\quickstart.ps1                │ (2 min)
│  B) Entender todos os detalhes:     │
│     Leia ARCHITECTURE.md            │ (15 min)
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│  4. Fazer deploy real:              │
│     Siga DEPLOYMENT.md              │ (30 min)
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│  5. Em caso de problemas:           │
│     Consulte QUICK_REFERENCE.md     │ (1 min)
└─────────────────────────────────────┘
```

---

## 🎯 Casos de Uso

### "Quero iniciar o load balancer agora"
1. Execute `quickstart.ps1`
2. Pronto! Load balancer em http://localhost:8084

### "Quero entender a arquitetura"
1. Leia `ARCHITECTURE.md` seção "Visão Geral"
2. Leia `ARCHITECTURE.md` seção "Componentes de Rede"
3. Pronto!

### "Estou recebendo erro X"
1. Vá para `QUICK_REFERENCE.md`
2. Procure por "Error: X"
3. Siga a solução

### "Preciso customizar o load balancer"
1. Edite `nginx.conf`
2. Execute `docker exec api-load-balancer nginx -s reload`
3. Pronto!

### "Como escalar para mais backends?"
1. Adicione server em `nginx.conf`, seção `upstream`
2. Execute `docker exec api-load-balancer nginx -s reload`
3. Pronto!

---

## ✅ Checklist de Setup

- [ ] Leu `OPTIMIZATION_SUMMARY.md`
- [ ] Leu `README.md`
- [ ] Copiou `.env.example` para `.env`
- [ ] Executou `validate-architecture.sh`
- [ ] Executou `quickstart.ps1` / `quickstart.sh`
- [ ] Testou `curl http://localhost:8084/health`
- [ ] Leu `ARCHITECTURE.md` (para detalhes)
- [ ] Leu `QUICK_REFERENCE.md` (para referência)

---

## 📊 Estrutura de Conteúdo

```
Documentação
├── Iniciantes
│   ├── OPTIMIZATION_SUMMARY.md    ← Comece aqui
│   ├── README.md
│   └── quickstart.sh / quickstart.ps1
├── Intermediário
│   ├── DEPLOYMENT.md
│   ├── ARCHITECTURE.md
│   └── validate-architecture.sh
├── Avançado
│   ├── QUICK_REFERENCE.md (troubleshooting)
│   ├── nginx.conf (configuração Nginx)
│   └── docker-compose-load-balancer.yml
└── Referência
    ├── health-check.sh
    ├── test-endpoints.sh
    ├── lb-manage.ps1
    └── .env.example
```

---

## 🆘 Ainda tem dúvidas?

1. ✅ Verifique se o arquivo que procura está listado acima
2. ✅ Use `Ctrl+F` / `Cmd+F` para buscar palavras-chave
3. ✅ Execute `validate-architecture.sh` para diagnóstico
4. ✅ Consulte `QUICK_REFERENCE.md` para problemas comuns
5. ✅ Leia `ARCHITECTURE.md` para entender a infraestrutura

---

## 📞 Informações Rápidas

**Load Balancer URL:** http://localhost:8084  
**Health Check:** http://localhost:8084/health  
**Nginx Status:** http://localhost:8084/nginx_status  

**Docker Compose:** `docker compose -f docker-compose-load-balancer.yml`  
**Serviços rodados:** 1 (load-balancer)  
**Redes usadas:** 1 (externa, do docker-compose-back.yml)  

**Otimização:** -85% de serviços duplicados, -100% de redes gerenciadas  
**Compatibilidade:** 100% com docker-compose-back.yml e docker-compose-infra.yml  

---

**Versão:** 1.0 (Enxuto e Otimizado)  
**Data de Atualização:** 05/02/2026  
**Status:** ✅ Pronto para Produção
