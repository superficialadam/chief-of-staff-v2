class CalendarAgent < BaseAgent
  def initialize(mcp_manager: nil)
    @mcp_manager = mcp_manager || Ai::McpManager.instance
    # Boot MCP if not already booted
    @mcp_manager.boot!(strict: false) unless @mcp_manager.booted
  end

  def update_event_context
    if @mcp_manager.booted
      time_min = Time.current
      time_max = time_min + 2.week
      time_min = time_min.iso8601
      time_max = time_max.iso8601
      result = @mcp_manager.call_tool("list-events", { "calendarId" => "primary", "timeMin" => time_min, "timeMax" => time_max })
      parse_events_text(result)
    end
  end

  def parse_events_text(response)
    text = response.first["text"]
    events_data = text.scan(/\d+\. Event: (.+)\nEvent ID: (.+)\nStart:(.+)\nEnd: (.+)\nView: (.+)/)
    pp events_data
    # 3. For each block, extract:
    #    - Event title (after "Event: ")
    #    - Event ID (after "Event ID: ")
    #    - Start time (after "Start: ")
    #    - End time (after "End: ")
    #    - URL (after "View: ")
    # 4. Return array of hashes
  end
end
