# Deploy no Google Compute Engine

## 1. Preparar a VM

Instale Git, Docker Engine, Docker Compose plugin e `curl`. O utilizador de deploy deve conseguir executar Docker e escrever no diretório escolhido para a aplicação.

Exemplo de diretório:

```text
/opt/facodi
```

Clone o repositório e escolha a branch do ambiente:

```bash
git clone https://github.com/marcelo-m7/facodi-odoo.git /opt/facodi
cd /opt/facodi
git checkout staging
cp .env.example .env
```

Edite `.env` e substitua obrigatoriamente as palavras-passe de exemplo.

## 2. Primeiro arranque

```bash
cd /opt/facodi
docker compose -f infrastructure/docker-compose.yml up -d db
bash scripts/deploy.sh staging
```

O script deteta se `facodi_core` já está instalado. Numa base nova usa `-i`; numa base existente usa `-u`.

## 3. Reverse proxy

O Compose publica Odoo apenas em loopback:

- `127.0.0.1:8069` para HTTP Odoo.
- `127.0.0.1:8072` para websocket/gevent.

O reverse proxy deve terminar TLS em 443 e encaminhar `/websocket` para 8072 e o restante tráfego para 8069.

## 4. GitHub Actions

Crie os environments `staging` e `production` e configure secrets.

Staging:

- `STAGING_HOST`
- `STAGING_USER`
- `STAGING_SSH_KEY`
- `STAGING_KNOWN_HOSTS`
- `STAGING_PATH`

Produção:

- `PRODUCTION_HOST`
- `PRODUCTION_USER`
- `PRODUCTION_SSH_KEY`
- `PRODUCTION_KNOWN_HOSTS`
- `PRODUCTION_PATH`

`*_PATH` deve apontar para o clone na VM, por exemplo `/opt/facodi`.

## 5. Fluxo de branches

```text
feature/* -> pull request -> staging -> validação -> pull request -> main
```

Um push em `staging` aciona o deploy de staging. Um push em `main` aciona produção. Para produção, recomenda-se configurar o GitHub Environment com aprovação obrigatória antes do job de deploy.

## 6. DNS e firewall

Aponte os registos A/AAAA do domínio do ambiente para os endereços externos da VM. No firewall da VPC, deixe públicos apenas 80/443; mantenha SSH restrito e não crie regras públicas para 8069, 8072 ou 5432.
