# frozen_string_literal: true

# Handles incoming Telegram webhook updates
class TelegramController < ApplicationController
  # Skip CSRF protection for webhook endpoint
  protect_from_forgery with: :null_session
  
  before_action :verify_telegram_token
  
  def webhook
    update = JSON.parse(request.body.read)
    
    # Extract message and user info
    message_text = extract_message_text(update)
    user_id = extract_user_id(update)
    
    if message_text.present? && user_id.present?
      # Process message through AI orchestrator
      response = process_message(message_text, user_id)
      
      # Send response back to Telegram
      send_telegram_message(user_id, response)
    end
    
    render json: { status: 'ok' }, status: :ok
    
  rescue JSON::ParserError => e
    Rails.logger.error "Invalid JSON in Telegram webhook: #{e.message}"
    render json: { error: 'Invalid JSON' }, status: :bad_request
    
  rescue => e
    Rails.logger.error "Telegram webhook error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Always return success to Telegram to prevent retries
    render json: { status: 'error_logged' }, status: :ok
  end
  
  private
  
  def verify_telegram_token
    # In development, allow bypassing verification for testing
    return if Rails.env.development? && ENV['TELEGRAM_WEBHOOK_VERIFICATION'] == 'disabled'
    
    token = ENV['TELEGRAM_BOT_TOKEN']
    if token.blank?
      Rails.logger.error "TELEGRAM_BOT_TOKEN not configured"
      render json: { error: 'Bot token not configured' }, status: :internal_server_error
      return false
    end
  end
  
  def extract_message_text(update)
    update.dig('message', 'text') || 
    update.dig('edited_message', 'text')
  end
  
  def extract_user_id(update)
    update.dig('message', 'chat', 'id') || 
    update.dig('edited_message', 'chat', 'id') ||
    update.dig('callback_query', 'from', 'id')
  end
  
  def process_message(text, user_id)
    Rails.logger.info "Processing Telegram message from user #{user_id}: #{text}"
    
    # Use the existing AI orchestrator
    orchestrator = get_orchestrator
    result = orchestrator.run!(text)
    
    # Format the response for Telegram
    format_telegram_response(result[:text])
    
  rescue => e
    Rails.logger.error "Failed to process message: #{e.message}"
    "I encountered an error processing your message. Please try again."
  end
  
  def get_orchestrator
    # Use singleton pattern to maintain state across requests
    @@orchestrator ||= Ai::Orchestrator.new
  end
  
  def format_telegram_response(text)
    # Telegram has a 4096 character limit per message
    # Also convert any HTML to Telegram-compatible Markdown
    formatted = text.to_s
      .gsub(/<\/?[^>]+>/, '') # Remove HTML tags
      .gsub(/\*\*(.+?)\*\*/, '*\1*') # Convert bold markdown
      .gsub(/`{3}[\w]*\n(.*?)\n`{3}/m, '```\1```') # Preserve code blocks
    
    # Truncate if too long
    if formatted.length > 4000
      formatted = formatted[0..3997] + "..."
    end
    
    formatted
  end
  
  def send_telegram_message(chat_id, text)
    bot_token = ENV['TELEGRAM_BOT_TOKEN']
    url = "https://api.telegram.org/bot#{bot_token}/sendMessage"
    
    payload = {
      chat_id: chat_id,
      text: text,
      parse_mode: 'Markdown',
      disable_web_page_preview: true
    }
    
    response = Faraday.post(url) do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = payload.to_json
      req.options.timeout = 10
    end
    
    result = JSON.parse(response.body)
    
    unless result['ok']
      Rails.logger.error "Failed to send Telegram message: #{result['description']}"
    end
    
    result
    
  rescue => e
    Rails.logger.error "Error sending Telegram message: #{e.message}"
    nil
  end
end