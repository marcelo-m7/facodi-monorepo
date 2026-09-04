# FACODI Odoo

Infraestrutura e addons Odoo para o **FACODI — Faculdade Comunitária Digital**.

Este repositório mantém, numa única base versionada, o código dos addons FACODI e a configuração necessária para executar Odoo Community em infraestrutura própria no Google Cloud.

## Arquitetura

```text
GitHub
├── branch staging ───────────────► staging.facodi.pt
└── branch main ──────────────────► facodi.pt
                                      │
                                      ▼
                              Google Compute Engine
                              ├── Docker Compose
                              ├── Odoo 19 Community
                              ├── PostgreSQL 16
                              └── addons FACODI
```

A VM é ligada à VPC dual-stack do projeto FACODI. Apenas HTTP/HTTPS devem ficar expostos publicamente; Odoo e PostgreSQL permanecem atrás do reverse proxy/rede interna.

## Estrutura

```text
addons/
  facodi_core/          núcleo inicial do addon Odoo
infrastructure/
  docker-compose.yml   runtime local/VM
  odoo.conf.example    configuração base do Odoo
scripts/
  deploy.sh            atualização segura da instância
  healthcheck.sh       verificação HTTP
.github/workflows/
  ci.yml               validação do addon
  deploy-staging.yml   deploy da branch staging
  deploy-production.yml deploy da branch main
docs/
  architecture.md
  deployment.md
```

## Desenvolvimento local

1. Copie `.env.example` para `.env`.
2. Defina `POSTGRES_PASSWORD` e `ODOO_DB`.
3. Execute:

```bash
docker compose -f infrastructure/docker-compose.yml up -d
```

Odoo fica disponível em `http://localhost:8069`.

Para instalar/atualizar o addon:

```bash
docker compose -f infrastructure/docker-compose.yml exec -T odoo \
  odoo -d "$ODOO_DB" -i facodi_core --stop-after-init
```

ou, após já estar instalado:

```bash
docker compose -f infrastructure/docker-compose.yml exec -T odoo \
  odoo -d "$ODOO_DB" -u facodi_core --stop-after-init
```

## Estratégia de ambientes

- `staging`: integração contínua e validação funcional.
- `main`: produção.
- Banco de dados e filestore são persistentes e **não** fazem parte do repositório.
- Secrets nunca devem ser commitados; deploy usa GitHub Actions secrets.

## Secrets esperados no GitHub

### Staging

- `STAGING_HOST`
- `STAGING_USER`
- `STAGING_SSH_KEY`
- `STAGING_PATH`

### Produção

- `PRODUCTION_HOST`
- `PRODUCTION_USER`
- `PRODUCTION_SSH_KEY`
- `PRODUCTION_PATH`

## Estado

Base inicial de infraestrutura e desenvolvimento. O objetivo imediato é ter uma instância Odoo 19 Community reproduzível, com addon FACODI versionado no GitHub e deploy separado para staging e produção.
