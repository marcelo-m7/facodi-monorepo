# Deploy no Google Compute Engine

## 1. Preparar a VM

Instale Docker Engine, Docker Compose plugin, Google Cloud CLI e `curl`. O utilizador de deployment deve conseguir executar Docker e escrever no diretório de deployment.

Diretório recomendado:

```text
/opt/facodi
```

A VM não precisa de clonar `facodi-monorepo`. O pipeline copia somente o Compose e os scripts de runtime.

Crie `/opt/facodi/.env` a partir de `.env.example`, substituindo as palavras-passe de exemplo:

```text
POSTGRES_USER=odoo
POSTGRES_PASSWORD=<strong-secret>
ODOO_DB=facodi
ODOO_ADMIN_PASSWD=<strong-secret>
FACODI_MODULES=facodi_learning,theme_facodi
```

Se um ambiente existente ainda tiver `website_facodi` na variável `FACODI_MODULES`, o novo `deploy-image.sh` normaliza esse token em memória durante o primeiro deployment. Atualize o `.env` permanente para `theme_facodi` após a transição.

## 2. Identidade da VM

Associe à VM uma service account própria com permissão de leitura no Artifact Registry FACODI. `deploy-image.sh` obtém um token curto através de `gcloud auth print-access-token` e autentica o Docker no registry. Nenhuma chave JSON é copiada do GitHub.

## 3. Primeiro deployment com `theme_facodi`

Antes do primeiro deployment desta evolução numa base que já tenha `website_facodi`, crie um backup consistente de:

```text
PostgreSQL database + Odoo filestore
```

A imagem antiga isoladamente não é um rollback completo porque a transição remove metadata do antigo addon de apresentação.

O pipeline deve copiar para `/opt/facodi`:

```text
infrastructure/docker-compose.yml
scripts/deploy-image.sh
scripts/migrate-theme-module-name.sh
scripts/apply-facodi-theme.sh
scripts/healthcheck.sh
```

Execute:

```bash
cd /opt/facodi
bash scripts/deploy-image.sh \
  europe-southwest1-docker.pkg.dev/<project>/<repository>/<image>:<commit-sha>
```

O script executa a sequência:

1. autentica Docker no Artifact Registry e faz pull da imagem exata;
2. inicia PostgreSQL e para o processo Odoo persistente antes de tocar na metadata;
3. executa a transição guardada do antigo `website_facodi`, se ele existir;
4. determina se `facodi_learning` e `theme_facodi` devem ser instalados ou atualizados;
5. executa Odoo com `--stop-after-init` para instalação/upgrade;
6. aplica `theme_facodi` a cada website através do método standard Odoo `button_choose_theme()`;
7. inicia Odoo a partir da imagem imutável;
8. valida `/web/login` com o health check.

### Guardas da transição legada

`scripts/migrate-theme-module-name.sh` recusa a alteração se encontrar uma situação que não corresponde ao antigo addon conhecido. Em particular, aborta quando:

- `website_facodi` e `theme_facodi` já coexistem no registry;
- `website_facodi` possui XML IDs inesperados; ou
- outra view personalizada herda da antiga `website_facodi.website_layout`.

O script não modifica `website_page` e não tenta converter XML IDs de uma view normal em templates de theme.

## 4. Reverse proxy

O Compose publica Odoo apenas em loopback:

- `127.0.0.1:8069` — HTTP Odoo;
- `127.0.0.1:8072` — websocket/gevent.

O reverse proxy deve terminar TLS em 443, encaminhar `/websocket` para 8072 e o restante tráfego para 8069.

## 5. GitHub Actions e Workload Identity Federation

Repository Actions variables:

```text
GCP_PROJECT_ID
GCP_REGION
GCP_ARTIFACT_REPOSITORY
FACODI_IMAGE_NAME
GCP_WORKLOAD_IDENTITY_PROVIDER
GCP_GITHUB_SERVICE_ACCOUNT
DEPLOY_STAGING_ENABLED=false
DEPLOY_PRODUCTION_ENABLED=false
```

Environment variables:

```text
STAGING_VM_NAME
STAGING_VM_ZONE
STAGING_DEPLOY_PATH=/opt/facodi
PRODUCTION_VM_NAME
PRODUCTION_VM_ZONE
PRODUCTION_DEPLOY_PATH=/opt/facodi
```

Não configure um secret contendo service-account JSON.

## 6. Fluxo de branches

```text
feature/* -> pull request -> staging -> validação -> pull request -> main
```

Um push em `staging`, quando habilitado, constrói a imagem SHA e publica em staging. Um push em `main` faz o mesmo para produção. Recomenda-se aprovação obrigatória no GitHub Environment `production`.

## 7. DNS e firewall

Aponte A/AAAA para os endereços externos da VM apenas quando o reverse proxy/TLS estiver pronto. Mantenha públicos somente 80/443; não exponha 8069, 8072 ou 5432.

## 8. Rollback

Para releases sem alteração de dados, redeploy de uma imagem SHA anterior é suficiente.

Para o primeiro deployment que efetua a transição `website_facodi -> theme_facodi`, se for necessário voltar atrás, restaure **a base PostgreSQL e o filestore pré-deployment** juntamente com a imagem antiga. Não reconstrua manualmente a metadata antiga do módulo.

Consulte `docs/ci-cd.md` para o fluxo completo de build/delivery e `docs/architecture.md` para a razão desta fronteira de rollback.
