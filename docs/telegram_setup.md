# Telegram Integration Setup

This document describes how to set up and use the Telegram bot integration with Chief of Staff v2.

## Overview

The Telegram integration allows users to interact with the AI assistant through Telegram messages. The system supports two modes:

1. **Development Mode**: Webhooks are forwarded through a reverse SSH tunnel to your local Rails instance
2. **Production Mode**: Webhooks are routed directly to the deployed Rails container

Both modes use the same stable webhook URL: `https://cos.dev.its75am.com/webhooks/telegram`

## Prerequisites

- Telegram Bot Token (from @BotFather)
- 1Password CLI configured with credentials
- Rails application running
- SSH access to the server (for dev mode)

## Environment Variables

The following environment variables are required (stored in 1Password):

```bash
TELEGRAM_BOT_TOKEN=op://Dev/cos_app/telegram_bot_token
TELEGRAM_CHAT_ID=op://Dev/cos_app/telegram_chat_id
TELEGRAM_WEBHOOK_URL=https://cos.dev.its75am.com/webhooks/telegram
```

## Setup Instructions

### 1. Install Dependencies

```bash
bundle install
```

### 2. Development Mode Setup

For local development with webhook forwarding:

#### Step 1: Start Rails locally
```bash
rails s
```

#### Step 2: Set up reverse SSH tunnel (in new terminal)
```bash
bin/telegram_dev_tunnel
```
This forwards server port 4000 to your local Rails on port 3000.

#### Step 3: Register the webhook
```bash
# Register webhook with Telegram (1Password resolves credentials automatically)
op run --env-file=.env -- bin/telegram_webhook register
```

### 3. Production Mode Setup

For production deployment:

#### Step 1: Deploy with Kamal
```bash
kamal deploy
```

#### Step 2: Register the webhook
```bash
# Register with 1Password credentials
op run --env-file=.env -- bin/telegram_webhook register
```

## Usage

### Managing the Webhook

All webhook commands should be run with 1Password to resolve credentials:

```bash
# Check webhook status
op run --env-file=.env -- bin/telegram_webhook info

# Register webhook
op run --env-file=.env -- bin/telegram_webhook register

# Delete webhook
op run --env-file=.env -- bin/telegram_webhook delete

# Test bot connection
op run --env-file=.env -- bin/telegram_webhook test

# Override webhook URL for testing
op run --env-file=.env -- bin/telegram_webhook register --url https://example.com/webhook
```

### Testing the Integration

1. Open Telegram and find your bot
2. Send a message to the bot
3. The bot will process your message through the AI orchestrator
4. You'll receive a response with the AI's answer

## Architecture

```
Telegram User
    ↓
Telegram API
    ↓
Webhook (https://cos.dev.its75am.com/webhooks/telegram)
    ↓
Kamal Proxy
    ↓
[Dev Mode: SSH Tunnel → Local Rails]
[Prod Mode: Direct → Rails Container]
    ↓
TelegramController#webhook
    ↓
Ai::Orchestrator
    ↓
OpenAI API (with MCP tools)
    ↓
Response to Telegram User
```

## File Structure

```
app/
├── controllers/
│   └── telegram_controller.rb    # Webhook handler
config/
├── initializers/
│   └── telegram.rb               # Rails configuration
├── routes.rb                     # Webhook route
├── deploy.yml                    # Production Kamal config
└── deploy.dev.yml               # Development Kamal config
bin/
├── telegram_webhook             # Webhook management script
├── telegram_dev_tunnel          # SSH tunnel helper
└── setup_telegram_proxy         # Proxy configuration helper
```

## Troubleshooting

### Webhook not receiving messages
1. Check webhook status: `bin/telegram_webhook info`
2. Verify the webhook URL is correct
3. Check Rails logs for incoming requests
4. Ensure firewall allows HTTPS traffic

### Development tunnel issues
1. Verify Rails is running on port 3000
2. Check SSH connection to server
3. Ensure port 4000 is not in use on server
4. Check verbose SSH output for errors

### Bot not responding
1. Check TELEGRAM_BOT_TOKEN is set correctly
2. Verify AI orchestrator is initialized
3. Check Rails logs for errors
4. Ensure OpenAI API key is configured

### 1Password integration
1. Ensure 1Password CLI is installed: `brew install 1password-cli`
2. Sign in if needed: `eval $(op signin)`
3. Use `op run --env-file=.env` to resolve credentials
4. Verify credential paths match your 1Password vault structure

## Security Notes

- Bot token is stored securely in 1Password
- Webhook verification can be disabled in dev mode only
- All production traffic uses HTTPS
- CSRF protection is disabled for webhook endpoint only

## Next Steps

- Add inline keyboard support for interactive responses
- Implement user session management
- Add support for file uploads and media
- Implement command handlers for specific actions