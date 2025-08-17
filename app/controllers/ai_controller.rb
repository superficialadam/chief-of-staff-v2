class AiController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:chat]
  
  def index
    # Simple chat interface
  end
  
  def chat
    input = params[:message]
    
    return render json: { error: "Message is required" }, status: :bad_request if input.blank?
    
    result = orchestrator.run!(input)
    render json: result
  rescue => e
    Rails.logger.error "AI chat error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    render json: { error: e.message }, status: :internal_server_error
  end
  
  def health
    render json: orchestrator.health
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end
  
  private
  
  # Use a cached orchestrator instance per request cycle
  # This ensures MCP servers stay connected and reduces initialization overhead
  def orchestrator
    # Cache at the class level to persist across requests
    # This maintains MCP server connections
    @@orchestrator ||= begin
      Rails.logger.info "Initializing AI Orchestrator (singleton)..."
      Ai::Orchestrator.new
    end
  end
end