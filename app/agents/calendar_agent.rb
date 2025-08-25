class CalendarAgent < BaseAgent
  def initialize(mcp_manager: nil)
    @mcp_manager = mcp_manager || Ai::McpManager.instance
    # Boot MCP if not already booted
    @mcp_manager.boot!(strict: false) unless @mcp_manager.booted
  end

  def update_event_context
    if @mcp_manager.booted
      time_min = Time.current
      time_max = time_min + 2.weeks
      time_min = time_min.iso8601
      time_max = time_max.iso8601
      # Keep Time objects for database
      time_min_for_db = time_min
      time_max_for_db = time_max
      result = @mcp_manager.call_tool("list-events", { "calendarId" => "primary", "timeMin" => time_min, "timeMax" => time_max })
      events = parse_events_text(result)
      context = CalendarContext.first_or_create
      context.update!(events: events, time_min: time_min_for_db, time_max: time_max_for_db, fetched_at: Time.current)
      context
    end
  end

  def parse_events_text(response)
    text = response.first["text"]

    # Split into event blocks
    event_blocks = text.split(/\n\d+\. Event: /)
    event_blocks.shift  # Remove header

    events = event_blocks.map.with_index do |block, index|
      # Add back the "Event: " part we split on
      block = "Event: " + block if index > 0

      # Parse each line
      event = {}
      block.split("\n").each do |line|
        case line
        when /^Event: (.+)$/
          event[:title] = $1
        when /^Event ID: (.+)$/
          event[:id] = $1
        when /^Start: (.+)$/
          event[:start] = $1.strip
        when /^End: (.+)$/
          event[:end] = $1.strip
        when /^Location: (.+)$/
          event[:location] = $1.strip
        when /^Guests: (.+)$/
          event[:guests] = $1.strip.split(", ").reject(&:empty?)
        when /^View: (.+)$/
          event[:url] = $1
        end
      end

      # Set defaults for missing optional fields
      event[:location] ||= ""
      event[:guests] ||= []

      event
    end

    events
  end
end
