# Deploy no Google Compute Engine

## 1. Preparar a VM

Instale Docker Engine, Docker Compose plugin, Google Cloud CLI e `curl`. O utilizador usado pelo mecanismo de `gcloud compute ssh` deve conseguir executar Docker e escrever no diretório de deployment.

Exemplo:

```text
/opt/facodi
```

A VM não precisa de clonar `facodi-monorepo` para executar a aplicação.

Crie apenas o diretório e o ficheiro persistente de configuração:

```bash
sudo mkdir -p /opt/facodi/infrastructure /opt/facodi/scripts
sudo chown -R "$USER":"$USER" /opt/facodi
cd /opt/facodi
```

Crie `/opt/facodi/.env` manualmente a partir de `.env.example` e substitua obrigatoriamente as palavras-passe de exemplo.

Valores essenciais:

```text
POSTGRES_USER=odoo
POSTGRES_PASSWORD=<strong-secret>
ODOO_DB=facodi
ODOO_ADMIN_PASSWD=<strong-secret>
FACODI_MODULES=facodi_learning,theme_facodi
```

## 2. Identidade da VM

Associe à VM uma service account própria com permissão de leitura no Artifact Registry usado pelo FACODI.

`deploy-image.sh` usa:

```bash
gcloud auth configure-docker <region>-docker.pkg.dev --quiet
```

A autenticação do pull é portanto obtida pela identidade da VM; nenhuma chave JSON do Google é copiada do GitHub.

## 3. Primeiro arranque

Depois de existir uma imagem no Artifact Registry e de `docker-compose.yml`, `deploy-image.sh` e `healthcheck.sh` terem sido copiados pelo pipeline:

```bash
cd /opt/facodi
bash scripts/deploy-image.sh \
  europe-southwest1-docker.pkg.dev/<project>/<repository>/<image>:<commit-sha>
```

O script:

1. autentica Docker no Artifact Registry;
2. faz pull apenas da imagem Odoo indicada;
3. sobe PostgreSQL;
4. deteta, para `facodi_learning` e `theme_facodi`, se cada módulo deve ser instalado ou atualizado;
5. executa a inicialização/upgrade Odoo com `--stop-after-init`;
6. sobe o serviço Odoo;
7. valida `/web/login` com o health check.

## 4. Reverse proxy

O Compose publica Odoo apenas em loopback:

- `127.0.0.1:8069` para HTTP Odoo;
- `127.0.0.1:8072` para websocket/gevent.

O reverse proxy deve terminar TLS em 443 e encaminhar `/websocket` para 8072 e o restante tráfego para 8069.

## 5. GitHub Actions e Workload Identity Federation

Configure como **Repository Actions variables**:

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

A service account usada pelo GitHub deve ser federada ao repositório através de Workload Identity Federation e possuir apenas as permissões necessárias para publicar no Artifact Registry e operar o acesso de deployment à VM.

Não configure um secret contendo service-account JSON.

### Staging environment

```text
STAGING_VM_NAME
STAGING_VM_ZONE
STAGING_DEPLOY_PATH=/opt/facodi
```

### Production environment

```text
PRODUCTION_VM_NAME
PRODUCTION_VM_ZONE
PRODUCTION_DEPLOY_PATH=/opt/facodi
```

Ative cada variável `DEPLOY_*_ENABLED` apenas quando o ambiente correspondente estiver pronto.

## 6. Fluxo de branches

```text
feature/* -> pull request -> staging -> validação -> pull request -> main
```

Um push em `staging`, quando habilitado, constrói a imagem SHA e publica em staging. Um push em `main`, quando habilitado, faz o mesmo para produção.

Para produção, recomenda-se configurar o GitHub Environment `production` com aprovação obrigatória antes do job de deploy.

## 7. DNS e firewall

Aponte os registos A/AAAA do domínio do ambiente para os endereços externos da VM. No firewall da VPC, deixe públicos apenas 80/443; mantenha acesso administrativo restrito e não crie regras públicas para 8069, 8072 ou 5432.

## 8. Rollback

O rollback de aplicação consiste em executar `deploy-image.sh` com um SHA antigo conhecido no Artifact Registry.

Esse mecanismo não substitui backups. Se uma versão de addon executar migrations irreversíveis, restaure também o PostgreSQL/filestore correspondentes conforme a política de backup.

Para detalhes de CI/CD, submodules e IAM, consulte `docs/ci-cd.md`.
