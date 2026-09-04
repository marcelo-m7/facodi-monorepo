# Arquitetura FACODI Odoo

## Princípios

1. Odoo 19 Community é o núcleo da aplicação e da gestão dos dados funcionais.
2. O código customizado vive em addons versionados neste repositório.
3. PostgreSQL e filestore são persistentes e independentes do ciclo de vida do código.
4. `staging` e `main` representam ambientes distintos, com bases e filestores distintos.
5. A infraestrutura começa simples: Compute Engine, Docker Compose e reverse proxy.
6. Serviços especializados podem ser extraídos futuramente para Cloud Run sem mover o núcleo do Odoo.

## Topologia

```text
GitHub
  ├─ staging ── CI ── SSH deploy ──► VM staging
  └─ main ───── CI ── SSH deploy ──► VM produção
                                      │
                               reverse proxy
                              /             \
                           :8069           :8072
                            Odoo          websocket
                              │
                          PostgreSQL
```

## Rede Google Cloud

A VPC FACODI é dual-stack.

- IPv4 privado sugerido para a subnet principal: `10.20.0.0/24`.
- IPv6: prefixo `/64` atribuído pelo Google Cloud, com acesso externo quando necessário.
- Entrada pública: TCP 80 e 443 para o reverse proxy.
- SSH: restrito a origem administrativa ou IAP.
- Odoo 8069/8072: ligados apenas ao loopback da VM no Compose.
- PostgreSQL 5432: não publicado no host e nunca exposto à Internet.

## Persistência

Volumes Docker separados:

- `postgres-data`: banco PostgreSQL.
- `odoo-data`: filestore e dados persistentes do Odoo.

Backups devem sempre considerar os dois componentes: dump PostgreSQL + filestore correspondente.

## Evolução

Cloud Run fica reservado para workloads stateless ou assíncronos, por exemplo ingestão, IA, transformação de conteúdos e webhooks. Esses serviços comunicam com o Odoo por APIs autenticadas e não substituem a persistência principal.
