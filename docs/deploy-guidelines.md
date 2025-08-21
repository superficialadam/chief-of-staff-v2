# Deployment Guidelines

This document outlines the successful deployment approach for the Chief of Staff Rails application using Kamal 2.

## Overview

The application is deployed to a single server using Kamal 2 with the following configuration:
- **Host**: 65.21.198.81
- **Domain**: cos.dev.its75am.com
- **HTTPS**: Automatic via Kamal proxy with Let's Encrypt
- **Database**: Existing PostgreSQL on host (not containerized)
- **Registry**: GitHub Container Registry (GHCR)

## Working Configuration

### 1. Environment Variables (.env)

```bash
# Rails Configuration
RAILS_MASTER_KEY=op://Dev/cos_app/rails_master_key

# OpenAI Configuration
OPENAI_PASSWORD=op://Dev/OPENAI/password
OPENAI_API_KEY=op://Dev/OPENAI/password

# PostgreSQL Configuration
PGHOST=host.docker.internal
PGPORT=5432
PGDATABASE=op://Dev/cos_app/db_name
PGUSER=op://Dev/cos_app/db_user
PGPASSWORD=op://Dev/cos_app/db_password

# GitHub Container Registry
GHCR_USER=op://Dev/GHDR/username
GHCR_TOKEN=op://Dev/GHDR/password
KAMAL_REGISTRY_PASSWORD=op://Dev/GHDR/password

# Telegram Bot Configuration
TELEGRAM_BOT_TOKEN=op://Dev/cos_app/telegram_bot_token
TELEGRAM_CHAT_ID=op://Dev/cos_app/telegram_chat_id
TELEGRAM_WEBHOOK_URL=https://cos.dev.its75am.com/cos
TELEGRAM_WEBHOOK_VERIFICATION=enabled
```

**Key Points:**
- Use 1Password references (`op://`) for secrets
- `PGHOST=host.docker.internal` for container-to-host database access
- Webhook URL matches the deployed domain

### 2. Kamal Configuration (config/deploy.yml)

```yaml
service: cos
image: ghcr.io/superficialadam/chief-of-staff-v2

servers:
  - 65.21.198.81

ssh:
  user: adam

proxy:
  host: cos.dev.its75am.com
  app_port: 80
  ssl: true
  healthcheck:
    path: /up
    interval: 5
    timeout: 2

registry:
  server: ghcr.io
  username: superficialadam
  password:
    - GHCR_TOKEN

env:
  clear:
    RAILS_ENV: production
    RAILS_LOG_TO_STDOUT: "1"
    RAILS_SERVE_STATIC_FILES: "1"
    PORT: "80"
    SOLID_QUEUE_IN_PUMA: "true"
  secret:
    - RAILS_MASTER_KEY
    - OPENAI_PASSWORD
    - OPENAI_API_KEY
    - PGHOST
    - PGPORT
    - PGDATABASE
    - PGUSER
    - PGPASSWORD
    - TELEGRAM_BOT_TOKEN
    - TELEGRAM_CHAT_ID

volumes:
  - "/var/lib/cos/storage:/rails/storage"

asset_path: /rails/public/assets

# Runtime options for Docker network connectivity
servers:
  web:
    hosts:
      - 65.21.198.81
    options:
      add-host: ["host.docker.internal:host-gateway"]

builder:
  arch: amd64
```

**Key Points:**
- `ssl: true` enables automatic HTTPS with Let's Encrypt
- Registry password uses array format: `password: - GHCR_TOKEN`
- `add-host: host.docker.internal:host-gateway` enables database connectivity
- No PostgreSQL accessory since using existing host database

### 3. Kamal Secrets (.kamal/secrets)

```bash
# This file tells Kamal to use environment variables
# The actual values come from .env via: op run --env-file=.env -- kamal deploy
RAILS_MASTER_KEY=${RAILS_MASTER_KEY}
OPENAI_PASSWORD=${OPENAI_PASSWORD}
OPENAI_API_KEY=${OPENAI_API_KEY}
PGHOST=${PGHOST}
PGPORT=${PGPORT}
PGDATABASE=${PGDATABASE}
PGUSER=${PGUSER}
PGPASSWORD=${PGPASSWORD}
GHCR_USER=${GHCR_USER}
GHCR_TOKEN=${GHCR_TOKEN}
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
```

**Key Points:**
- References environment variables using `${VAR_NAME}` syntax
- Works with `op run --env-file=.env` to resolve 1Password secrets

## Critical Fixes Applied

### 1. Database Connectivity Issues

**Problem**: Container couldn't connect to host PostgreSQL database.

**Root Causes**:
- Kamal network uses `172.18.0.0/16`, not the default Docker bridge `172.17.0.0/16`
- PostgreSQL `pg_hba.conf` only allowed connections from `172.17.0.0/16`
- Database host configuration was incorrect

**Solutions**:
1. **Updated pg_hba.conf** on the server:
   ```bash
   sudo sed -i 's/172.17.0.0\/16/172.0.0.0\/8/g' /etc/postgresql/16/main/pg_hba.conf
   sudo systemctl reload postgresql
   ```

2. **Used host.docker.internal** in environment:
   ```bash
   PGHOST=host.docker.internal
   ```

3. **Added host mapping** in deploy.yml:
   ```yaml
   options:
     add-host: ["host.docker.internal:host-gateway"]
   ```

### 2. Rails Master Key Issues

**Problem**: "ArgumentError: key must be 16 bytes" during deployment.

**Root Cause**: 1Password secret references weren't being resolved correctly, or the key was truncated.

**Solution**: Ensured 1Password references are consistent and properly formatted:
```bash
RAILS_MASTER_KEY=op://Dev/cos_app/rails_master_key  # Consistent casing
```

### 3. Unnecessary Database Migration

**Problem**: Container hung during `db:prepare` in docker-entrypoint.

**Root Cause**: The default Rails Docker entrypoint runs `db:prepare` which wasn't needed since the database already exists.

**Solution**: Modified `bin/docker-entrypoint` to skip database preparation:
```bash
# Skip db:prepare - database is already set up and managed separately
# if [ "${@: -2:1}" == "./bin/rails" ] && [ "${@: -1:1}" == "server" ]; then
#   ./bin/rails db:prepare
# fi
```

### 4. MCP Server Credentials

**Problem**: Production container failed looking for `credentials.json` file.

**Root Cause**: MCP (Model Context Protocol) manager tried to initialize in production without required credential files.

**Solution**: Disabled MCP in production environment:
```ruby
# app/services/ai/mcp_manager.rb
def boot!(strict: false)
  return if @booted
  
  # Skip MCP in production for now
  if Rails.env.production?
    Rails.logger.info "MCP Manager disabled in production"
    @booted = true
    return
  end
  
  # ... rest of initialization
end
```

### 5. Registry Configuration Format

**Problem**: Docker registry authentication failed.

**Root Cause**: Incorrect password format in deploy.yml.

**Solution**: Used array format for registry password:
```yaml
# Wrong:
registry:
  password: <%= ENV["GHCR_TOKEN"] %>

# Correct:
registry:
  password:
    - GHCR_TOKEN
```

## Deployment Commands

### Initial Deployment
```bash
op run --env-file=.env -- kamal deploy
```

### Subsequent Deployments
```bash
op run --env-file=.env -- kamal deploy
```

### Restart Without Code Changes
```bash
op run --env-file=.env -- kamal redeploy
```

### Setup Telegram Webhook
```bash
./bin/setup-telegram-webhook
```

## Common Traps & Troubleshooting

### 1. Database Connection Fails
- **Check**: Is PostgreSQL listening on Docker bridge networks?
  ```bash
  sudo netstat -tlnp | grep :5432
  ```
- **Check**: Is pg_hba.conf allowing Docker network connections?
  ```bash
  sudo grep 172 /etc/postgresql/16/main/pg_hba.conf
  ```
- **Fix**: Update pg_hba.conf to allow `172.0.0.0/8` range

### 2. Container Hangs During Startup
- **Check**: Container logs for specific errors
  ```bash
  kamal app logs
  ```
- **Common cause**: db:prepare hanging due to database connectivity
- **Fix**: Skip unnecessary database operations in docker-entrypoint

### 3. Registry Authentication Fails
- **Check**: Registry configuration format in deploy.yml
- **Fix**: Use array format: `password: - GHCR_TOKEN`

### 4. HTTPS Not Working
- **Check**: `ssl: true` is set in proxy configuration
- **Fix**: Redeploy and run `kamal proxy reboot` if needed

### 5. Environment Variables Not Available
- **Check**: Variables are listed in `env.secret` section of deploy.yml
- **Check**: 1Password references have consistent casing
- **Fix**: Ensure .kamal/secrets file references env vars with `${VAR_NAME}`

## Network Architecture

```
Internet (HTTPS) → Kamal Proxy → Rails Container
                                      ↓
                               host.docker.internal
                                      ↓
                              PostgreSQL (Host)
```

**Key Points**:
- Kamal proxy handles SSL termination and routing
- Containers run in custom `kamal` network (172.18.0.0/16)
- Database access via host network using `host.docker.internal`
- No need for separate database container since host DB exists

## File Structure

```
.
├── .env                      # 1Password secret references
├── .kamal/
│   └── secrets              # Environment variable mappings
├── config/
│   └── deploy.yml           # Kamal deployment configuration
├── bin/
│   ├── docker-entrypoint    # Modified to skip db:prepare
│   └── setup-telegram-webhook # Webhook setup script
└── docs/
    └── deploy-guidelines.md # This file
```

## Success Criteria

A successful deployment should result in:
- ✅ App accessible at https://cos.dev.its75am.com
- ✅ Health check passes at https://cos.dev.its75am.com/up
- ✅ Database connectivity working
- ✅ Telegram webhook configured and responding
- ✅ No errors in container logs
- ✅ SSL certificate auto-provisioned and working

## Maintenance Commands

```bash
# Check app status
kamal app details

# View logs
kamal app logs -f

# SSH into container
kamal app exec -i bash

# Check webhook status  
kamal app exec 'bin/rails telegram:webhook_info'

# Restart proxy
kamal proxy reboot

# Full status check
kamal details
```

This configuration has been tested and works reliably for production deployment of the Chief of Staff Rails application.