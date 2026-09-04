#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${FACODI_ENV_FILE:-.env}"

usage() {
  cat <<'EOF'
FACODI Google Cloud login helper

Usage:
  bash scripts/gcp-login.sh

Optional environment variable:
  FACODI_ENV_FILE   dotenv file to update (default: .env)

The script installs Google Cloud CLI only after confirmation, performs an
interactive Google login, validates the selected project, and stores only
non-sensitive FACODI/GCP configuration values in the dotenv file.
Google OAuth credentials remain in gcloud's own credential store.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

log() {
  printf '[facodi-gcp-login] %s\n' "$*"
}

die() {
  printf '[facodi-gcp-login] ERRO: %s\n' "$*" >&2
  exit 1
}

run_privileged() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    command -v sudo >/dev/null 2>&1 || die "sudo não está instalado; não é possível instalar o Google Cloud CLI automaticamente"
    sudo "$@"
  fi
}

install_gcloud_debian() {
  command -v apt-get >/dev/null 2>&1 || die "apt-get não encontrado; instalação automática suporta Debian/Ubuntu/ChromeOS Linux"
  command -v curl >/dev/null 2>&1 || {
    log "curl não encontrado; instalando pré-requisitos"
    run_privileged apt-get update
    run_privileged apt-get install -y ca-certificates gnupg curl
  }

  log "Instalando pré-requisitos do Google Cloud CLI..."
  run_privileged apt-get update
  run_privileged apt-get install -y ca-certificates gnupg curl

  log "Configurando o repositório oficial do Google Cloud CLI..."
  run_privileged install -d -m 0755 /usr/share/keyrings
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | if [[ "$(id -u)" -eq 0 ]]; then
        gpg --dearmor --yes -o /usr/share/keyrings/cloud.google.gpg
      else
        sudo gpg --dearmor --yes -o /usr/share/keyrings/cloud.google.gpg
      fi

  printf '%s\n' 'deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main' \
    | if [[ "$(id -u)" -eq 0 ]]; then
        tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
      else
        sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
      fi

  run_privileged apt-get update
  run_privileged apt-get install -y google-cloud-cli
}

install_gcloud_if_needed() {
  if command -v gcloud >/dev/null 2>&1; then
    log "Google Cloud CLI encontrado: $(command -v gcloud)"
    return 0
  fi

  printf 'Google Cloud CLI não está instalado. Deseja instalar agora? [y/N] '
  read -r answer
  case "${answer:-}" in
    y|Y|yes|YES|s|S|sim|SIM)
      ;;
    *)
      die "instalação cancelada pelo utilizador"
      ;;
  esac

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
  else
    die "não foi possível identificar a distribuição Linux"
  fi

  case "${ID:-}" in
    debian|ubuntu)
      install_gcloud_debian
      ;;
    *)
      die "instalação automática não suportada para ${PRETTY_NAME:-${ID:-este sistema}}; instale o Google Cloud CLI manualmente"
      ;;
  esac

  command -v gcloud >/dev/null 2>&1 || die "Google Cloud CLI não foi encontrado após a instalação"
  log "Google Cloud CLI instalado com sucesso"
}

upsert_env() {
  local key="$1"
  local value="$2"
  local tmp
  tmp="$(mktemp "${ENV_FILE##*/}.XXXXXX")"

  if [[ -f "$ENV_FILE" ]]; then
    awk -v key="$key" -v value="$value" '
      BEGIN { replaced = 0 }
      $0 ~ ("^" key "=") {
        if (!replaced) {
          print key "=" value
          replaced = 1
        }
        next
      }
      { print }
      END {
        if (!replaced) print key "=" value
      }
    ' "$ENV_FILE" > "$tmp"
  else
    printf '%s=%s\n' "$key" "$value" > "$tmp"
  fi

  mv "$tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

install_gcloud_if_needed

echo
echo '=== FACODI — Google Cloud Login ==='
echo
log "Abrindo autenticação Google..."
gcloud auth login

echo
log "Projetos acessíveis pela conta autenticada:"
gcloud projects list --format='table(projectId,name)'

echo
read -r -p 'Digite o PROJECT ID do projeto FACODI: ' GCP_PROJECT_ID
[[ -n "$GCP_PROJECT_ID" ]] || die "PROJECT ID não pode estar vazio"

log "Validando acesso ao projeto $GCP_PROJECT_ID..."
gcloud projects describe "$GCP_PROJECT_ID" >/dev/null || die "não foi possível aceder ao projeto $GCP_PROJECT_ID"
gcloud config set project "$GCP_PROJECT_ID" >/dev/null

GCP_PROJECT_NUMBER="$(gcloud projects describe "$GCP_PROJECT_ID" --format='value(projectNumber)')"
GCP_AUTH_ACCOUNT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n1)"

[[ -n "$GCP_PROJECT_NUMBER" ]] || die "não foi possível obter o número do projeto"
[[ -n "$GCP_AUTH_ACCOUNT" ]] || die "nenhuma conta gcloud ativa foi encontrada após o login"

GCP_REGION="${GCP_REGION:-europe-southwest1}"
GCP_ZONE="${GCP_ZONE:-${GCP_REGION}-b}"
GCP_NETWORK="${GCP_NETWORK:-facodi-vpc}"
GCP_SUBNET="${GCP_SUBNET:-facodi-madrid}"
GCP_ARTIFACT_REPOSITORY="${GCP_ARTIFACT_REPOSITORY:-facodi}"
FACODI_IMAGE_NAME="${FACODI_IMAGE_NAME:-odoo}"
STAGING_VM_NAME="${STAGING_VM_NAME:-facodi-app-01}"
STAGING_DEPLOY_PATH="${STAGING_DEPLOY_PATH:-/opt/facodi}"
GCP_WIF_POOL="${GCP_WIF_POOL:-github}"
GCP_WIF_PROVIDER="${GCP_WIF_PROVIDER:-facodi-monorepo}"
GCP_DEPLOY_SERVICE_ACCOUNT="${GCP_DEPLOY_SERVICE_ACCOUNT:-facodi-github-deploy}"
GCP_RUNTIME_SERVICE_ACCOUNT="${GCP_RUNTIME_SERVICE_ACCOUNT:-facodi-runtime}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-marcelo-m7/facodi-monorepo}"

if [[ ! -e "$ENV_FILE" ]]; then
  umask 077
  cat > "$ENV_FILE" <<'EOF'
# FACODI local environment
# Google OAuth credentials are intentionally NOT stored in this file.
EOF
fi

upsert_env GCP_PROJECT_ID "$GCP_PROJECT_ID"
upsert_env GCP_PROJECT_NUMBER "$GCP_PROJECT_NUMBER"
upsert_env GCP_REGION "$GCP_REGION"
upsert_env GCP_ZONE "$GCP_ZONE"
upsert_env GCP_NETWORK "$GCP_NETWORK"
upsert_env GCP_SUBNET "$GCP_SUBNET"
upsert_env GCP_ARTIFACT_REPOSITORY "$GCP_ARTIFACT_REPOSITORY"
upsert_env FACODI_IMAGE_NAME "$FACODI_IMAGE_NAME"
upsert_env STAGING_VM_NAME "$STAGING_VM_NAME"
upsert_env STAGING_DEPLOY_PATH "$STAGING_DEPLOY_PATH"
upsert_env GCP_WIF_POOL "$GCP_WIF_POOL"
upsert_env GCP_WIF_PROVIDER "$GCP_WIF_PROVIDER"
upsert_env GCP_DEPLOY_SERVICE_ACCOUNT "$GCP_DEPLOY_SERVICE_ACCOUNT"
upsert_env GCP_RUNTIME_SERVICE_ACCOUNT "$GCP_RUNTIME_SERVICE_ACCOUNT"
upsert_env GITHUB_REPOSITORY "$GITHUB_REPOSITORY"
upsert_env GCP_AUTH_ACCOUNT "$GCP_AUTH_ACCOUNT"

chmod 600 "$ENV_FILE"

cat <<EOF

Configuração FACODI atualizada em:
  $ENV_FILE

Conta Google ativa:
  $GCP_AUTH_ACCOUNT

Projeto:
  $GCP_PROJECT_ID

Project number:
  $GCP_PROJECT_NUMBER

As credenciais OAuth não foram gravadas no .env; permanecem no armazenamento do gcloud.

Para carregar as variáveis desta sessão:
  set -a
  source "$ENV_FILE"
  set +a

Depois pode executar:
  bash infrastructure/gcp/bootstrap-staging.sh
  bash infrastructure/gcp/validate-staging.sh
EOF
