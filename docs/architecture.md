# Arquitetura FACODI Odoo

## Princípios

1. Odoo 19 Community é o núcleo da aplicação e da gestão dos dados funcionais.
2. Os addons funcionais vivem em repositórios separados e são fixados no monorepo por Git submodules.
3. O monorepo é responsável por composição, build, CI/CD e runtime, não pela implementação interna dos addons.
4. PostgreSQL e filestore são persistentes e independentes do ciclo de vida da imagem.
5. `staging` e `main` representam ambientes distintos, com bases e filestores distintos.
6. O runtime usa imagens Docker imutáveis identificadas pelo SHA do commit do monorepo.
7. GitHub autentica no Google Cloud através de OIDC + Workload Identity Federation.
8. Serviços especializados podem ser extraídos futuramente para Cloud Run sem mover o núcleo do Odoo.

## Addons

```text
marcelo-m7/facodi-learning
  -> addons/facodi-learning
  -> technical module: facodi_learning

marcelo-m7/facodi-theme
  -> addons/facodi-theme
   -> technical module: theme_facodi
```

O nome do repositório não precisa ser igual ao nome técnico do módulo Odoo. O monorepo guarda o Gitlink de cada submodule, logo cada commit do monorepo define exatamente as versões dos dois addons usadas no build.

## Topologia

```text
GitHub repositories
   |
   | recursive submodule checkout
   v
facodi-monorepo
   |
   | GitHub Actions + OIDC/WIF
   v
Artifact Registry
   |
   | immutable image :<monorepo-sha>
   v
Compute Engine VM
   |
   +-- reverse proxy -> 127.0.0.1:8069 / 8072
   +-- Odoo 19 container
   +-- PostgreSQL 16 container
   +-- persistent postgres-data
   +-- persistent odoo-data
```

A VM não precisa de um clone do código para executar a aplicação. O pipeline transfere apenas a definição de runtime e scripts de deployment.

## Rede Google Cloud

A VPC FACODI é dual-stack.

- IPv4 privado sugerido para a subnet principal: `10.20.0.0/24`.
- IPv6: prefixo `/64` atribuído pelo Google Cloud, com acesso externo quando necessário.
- Entrada pública: TCP 80 e 443 para o reverse proxy.
- SSH/OS Login: restrito ao mecanismo administrativo escolhido.
- Odoo 8069/8072: ligados apenas ao loopback da VM no Compose.
- PostgreSQL 5432: não publicado no host e nunca exposto à Internet.

## Persistência

Volumes Docker separados:

- `postgres-data`: banco PostgreSQL.
- `odoo-data`: filestore e dados persistentes do Odoo.

Backups devem sempre considerar os dois componentes: dump PostgreSQL + filestore correspondente.

## Supply chain e deployment

O container nunca executa Git. A sequência é:

```text
checkout + pinned submodules
        -> CI
        -> Docker build
        -> Artifact Registry :SHA
        -> Compute Engine pull :SHA
        -> Odoo module install/update
        -> health check
```

Rollback da aplicação significa selecionar uma imagem anterior conhecida. Rollback de dados continua dependente da compatibilidade das migrations e, quando necessário, de backup restaurado.

## Evolução

Cloud Run fica reservado para workloads stateless ou assíncronos, por exemplo ingestão, IA, transformação de conteúdos e webhooks. Esses serviços comunicam com o Odoo por APIs autenticadas e não substituem a persistência principal.
