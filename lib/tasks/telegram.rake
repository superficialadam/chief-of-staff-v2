# frozen_string_literal: true

namespace :telegram do
  desc "Set up Telegram webhook"
  task setup_webhook: :environment do
    bot_token = ENV['TELEGRAM_BOT_TOKEN']
    webhook_url = ENV['TELEGRAM_WEBHOOK_URL']
    
    if bot_token.blank?
      puts "Error: TELEGRAM_BOT_TOKEN not configured"
      exit 1
    end
    
    if webhook_url.blank?
      puts "Error: TELEGRAM_WEBHOOK_URL not configured"
      exit 1
    end
    
    # Set the webhook
    require 'faraday'
    url = "https://api.telegram.org/bot#{bot_token}/setWebhook"
    
    response = Faraday.post(url) do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        url: webhook_url,
        allowed_updates: ['message', 'edited_message', 'callback_query']
      }.to_json
      req.options.timeout = 30
    end
    
    result = JSON.parse(response.body)
    
    if result['ok']
      puts "✅ Webhook successfully set to: #{webhook_url}"
      puts "   Description: #{result['description']}"
    else
      puts "❌ Failed to set webhook: #{result['description']}"
      exit 1
    end
  end
  
  desc "Get current Telegram webhook info"
  task webhook_info: :environment do
    bot_token = ENV['TELEGRAM_BOT_TOKEN']
    
    if bot_token.blank?
      puts "Error: TELEGRAM_BOT_TOKEN not configured"
      exit 1
    end
    
    require 'faraday'
    url = "https://api.telegram.org/bot#{bot_token}/getWebhookInfo"
    
    response = Faraday.get(url)
    result = JSON.parse(response.body)
    
    if result['ok']
      info = result['result']
      puts "Webhook URL: #{info['url'] || 'Not set'}"
      puts "Pending updates: #{info['pending_update_count'] || 0}"
      puts "Last error: #{info['last_error_message'] || 'None'}" if info['last_error_date']
      puts "Max connections: #{info['max_connections'] || 40}"
    else
      puts "Failed to get webhook info: #{result['description']}"
    end
  end
  
  desc "Delete Telegram webhook (for testing with polling)"
  task delete_webhook: :environment do
    bot_token = ENV['TELEGRAM_BOT_TOKEN']
    
    if bot_token.blank?
      puts "Error: TELEGRAM_BOT_TOKEN not configured"
      exit 1
    end
    
    require 'faraday'
    url = "https://api.telegram.org/bot#{bot_token}/deleteWebhook"
    
    response = Faraday.post(url)
    result = JSON.parse(response.body)
    
    if result['ok']
      puts "✅ Webhook deleted successfully"
    else
      puts "❌ Failed to delete webhook: #{result['description']}"
    end
  end
  
  desc "Test sending a message to the configured chat"
  task test_message: :environment do
    bot_token = ENV['TELEGRAM_BOT_TOKEN']
    chat_id = ENV['TELEGRAM_CHAT_ID']
    
    if bot_token.blank? || chat_id.blank?
      puts "Error: TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID must be configured"
      exit 1
    end
    
    require 'faraday'
    url = "https://api.telegram.org/bot#{bot_token}/sendMessage"
    
    response = Faraday.post(url) do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        chat_id: chat_id,
        text: "🎉 Chief of Staff bot is online!\n\nDeployed at: #{Time.current}\nEnvironment: #{Rails.env}",
        parse_mode: 'Markdown'
      }.to_json
    end
    
    result = JSON.parse(response.body)
    
    if result['ok']
      puts "✅ Test message sent successfully!"
    else
      puts "❌ Failed to send message: #{result['description']}"
    end
  end
end