class AiController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:chat]
  
  def index
    # Simple chat interface
  end
  
  def chat
    orchestrator = Ai::Orchestrator.new
    input = params[:message]
    
    return render json: { error: "Message is required" }, status: :bad_request if input.blank?
    
    result = orchestrator.run!(input)
    render json: result
  rescue => e
    Rails.logger.error "AI chat error: #{e.message}"
    render json: { error: e.message }, status: :internal_server_error
  end
  
  def health
    orchestrator = Ai::Orchestrator.new
    render json: orchestrator.health
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end
end