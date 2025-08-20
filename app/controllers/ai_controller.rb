class AiController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :chat, :stream ]

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

  def stream
    input = params[:message]

    return render json: { error: "Message is required" }, status: :bad_request if input.blank?

    # Disable Rails buffering and set SSE headers
    response.headers["Content-Type"] = "text/event-stream; charset=utf-8"
    response.headers["Cache-Control"] = "no-cache, no-store"
    response.headers["Connection"] = "keep-alive"
    response.headers["X-Accel-Buffering"] = "no" # Disable Nginx buffering

    # Disable Rack::ETag and other middleware that might buffer
    self.response_body = Enumerator.new do |yielder|
      begin
        # Send initial event to indicate processing started
        yielder << "event: start\ndata: {\"status\":\"processing\"}\n\n"
        # TODO(human): Add flush mechanism here to force immediate delivery

        # Process the request with progress callback
        if orchestrator.respond_to?(:run_with_progress!)
          result = orchestrator.run_with_progress!(input) do |event_type, event_data|
            # Send progress events immediately
            case event_type
            when :tool_start
              yielder << "event: tool_start\ndata: #{event_data.to_json}\n\n"
              # TODO(human): Add flush mechanism here
            when :tool_complete
              yielder << "event: tool_complete\ndata: #{event_data.to_json}\n\n"
              # TODO(human): Add flush mechanism here
            when :iteration
              yielder << "event: iteration\ndata: #{event_data.to_json}\n\n"
              # TODO(human): Add flush mechanism here
            end
          end
        else
          # Fallback to regular processing
          result = orchestrator.run!(input)
        end

        # Send the complete result
        yielder << "event: complete\ndata: #{result.to_json}\n\n"
      rescue => e
        Rails.logger.error "AI stream error: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        yielder << "event: error\ndata: #{{ error: e.message }.to_json}\n\n"
      end
    end
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

