# frozen_string_literal: true

# Telegram Bot configuration
Rails.application.configure do
  config.telegram = ActiveSupport::OrderedOptions.new
  
  # Load configuration from environment
  config.telegram.bot_token = ENV['TELEGRAM_BOT_TOKEN']
  config.telegram.webhook_url = ENV['TELEGRAM_WEBHOOK_URL']
  config.telegram.webhook_verification = ENV.fetch('TELEGRAM_WEBHOOK_VERIFICATION', 'enabled')
  
  # Message settings
  config.telegram.max_message_length = 4096
  config.telegram.parse_mode = 'Markdown'
  
  # Log configuration status
  if Rails.env.development? || Rails.env.test?
    Rails.logger.info "Telegram configuration loaded (#{Rails.env} mode)"
    Rails.logger.info "Webhook URL: #{config.telegram.webhook_url}" if config.telegram.webhook_url.present?
    Rails.logger.warn "TELEGRAM_BOT_TOKEN not set" if config.telegram.bot_token.blank?
  elsif config.telegram.bot_token.blank?
    Rails.logger.error "TELEGRAM_BOT_TOKEN is required in production"
  end
end