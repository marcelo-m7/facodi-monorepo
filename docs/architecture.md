# Arquitetura FACODI Odoo

## Princípios

1. Odoo 19 Community é o núcleo da aplicação e da gestão dos dados funcionais.
2. Funcionalidades e apresentação estendem primeiro os mecanismos standard do Odoo.
3. Addons vivem em repositórios separados e são fixados no monorepo por Git submodules.
4. O monorepo é responsável por composição, build, CI/CD e runtime.
5. PostgreSQL e filestore são persistentes e independentes do ciclo de vida da imagem.
6. `staging` e `main` representam ambientes distintos, com bases e filestores distintos.
7. O runtime usa imagens Docker imutáveis identificadas pelo SHA do commit do monorepo.
8. GitHub autentica no Google Cloud através de OIDC + Workload Identity Federation.

## Composição Odoo

```text
Odoo 19 Community
├── website / Website Builder
├── website_slides
├── theme_common
│   └── pinned from odoo/design-themes
├── facodi_learning
└── theme_facodi
    ├── palette and Website theme values
    ├── editable FACODI snippets
    ├── narrow QWeb inheritance
    └── presentation-only website_slides styling
```

Pins de composição desta evolução:

```text
addons/facodi-theme
  -> eca3c2c5ec3e601559cb5d6e7415c892be938fd7
  -> technical module: theme_facodi

vendor/odoo-design-themes
  -> a1818df4ade65406c0cacae8b1ea676e6f70095f
  -> runtime module consumed: theme_common

addons/facodi-learning
  -> technical module: facodi_learning
```

O Dockerfile copia somente `theme_common` do repositório oficial de design themes. Isso mantém a dependência upstream explícita sem transformar todos os temas oficiais em módulos disponíveis na imagem FACODI.

## Regra standard-first do tema

`theme_facodi` não substitui o Website Builder nem cria rotas paralelas de aprendizagem. Odoo continua proprietário de:

- header/footer e respetivos controlos do Website Builder;
- logo e favicon;
- páginas e conteúdo editável;
- catálogo, cursos e lições de `website_slides`;
- seleção/aplicação de themes.

O addon FACODI acrescenta identidade visual, snippets editáveis e heranças estreitas. QWeb de apresentação não deve executar pesquisas de dados de negócio com `request.env`/`sudo()`.

A instalação do módulo e a seleção do theme são passos distintos no Odoo. Depois da instalação/upgrade, `scripts/apply-facodi-theme.sh` usa o método standard `ir.module.module.button_choose_theme()` com contexto `website_id` para aplicar `theme_facodi`.

## Configuração runtime do Odoo 19

`admin_passwd` é uma opção de ficheiro no Odoo 19 e não é passada pela linha de comandos. `docker/facodi-odoo-server.sh` gera dentro do container um ficheiro de configuração privado (`0600`) a partir do `ODOO_ADMIN_PASSWD` fornecido pelo `.env` protegido da VM e, em seguida, delega para o entrypoint oficial da imagem Odoo. O serviço persistente recebe ainda `-d` e `ODOO_DB` como argumentos separados, evitando seleção ambígua ou criação acidental de outra base.

## Transição do addon legado

A versão anterior usava um addon normal chamado `website_facodi`. Ele possuía uma única view herdada conhecida (`website_facodi.website_layout`) para adicionar a classe do site e a meta `theme-color`.

Converter esse registo diretamente para os XML IDs de um theme nativo é incorreto porque Odoo separa templates de theme (`theme.ir.ui.view`) das views copiadas para cada website.

Por isso a transição é deliberadamente conservadora:

```text
legacy website_facodi present?
       |
       +-- no -> no-op
       |
       +-- yes
            -> stop if theme_facodi already exists
            -> stop if unexpected legacy XML IDs exist
            -> stop if another custom view inherits the legacy view
            -> remove only known legacy view/module metadata
            -> install theme_facodi normally
            -> select theme with button_choose_theme()
```

A transição não edita `website_page`, menus ou conteúdo criado no Website Builder. Num ambiente existente, PostgreSQL e filestore devem ser copiados juntos antes do primeiro deployment desta mudança.

## Topologia

```text
GitHub repositories
   |
   | recursive submodule checkout
   v
facodi-monorepo
   |
   | CI + Docker build + OIDC/WIF
   v
Artifact Registry :<monorepo-sha>
   |
   v
Compute Engine VM
   |
   +-- reverse proxy -> 127.0.0.1:8069 / 8072
   +-- Odoo 19 immutable container
   +-- PostgreSQL 16 container
   +-- persistent postgres-data
   +-- persistent odoo-data
```

A VM não precisa de um clone do código. O pipeline transfere apenas a definição de runtime e os scripts de deployment.

## Rede Google Cloud

- VPC FACODI dual-stack.
- Subnet principal: `10.20.0.0/24` + prefixo IPv6 `/64` atribuído pelo Google Cloud.
- Entrada pública: somente TCP 80/443 para o reverse proxy.
- SSH/OS Login restrito ao mecanismo administrativo/IAP configurado.
- Odoo 8069/8072 ligados apenas ao loopback da VM.
- PostgreSQL 5432 não é publicado no host.

## Persistência e rollback

Volumes persistentes:

- `postgres-data`: PostgreSQL;
- `odoo-data`: filestore e estado persistente Odoo.

Rollback de imagem é suficiente apenas quando não houve mudança incompatível de dados. O primeiro deployment da transição `website_facodi -> theme_facodi` altera metadata de módulo/view; se for necessário revertê-lo, restaure o backup pré-deployment de PostgreSQL **e** filestore junto com a imagem anterior.

## Evolução futura

Cloud Run fica reservado para workloads stateless/assíncronos — ingestão, IA, transformação de conteúdos e webhooks. Esses serviços comunicam com Odoo por APIs autenticadas e não substituem a persistência principal.
