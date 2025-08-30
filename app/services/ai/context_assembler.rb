module Ai
  class ContextAssembler
    def self.build_context
      {
        current_time: Time.current,
        calendar: fetch_calendar_events,
        recent_chats: fetch_recent_chats,
        location: "Stockholm, Sweden"  # Or from user settings
      }
    end

    def self.format_for_llm
      context = build_context
      prompt = ""

      # Add current context
      prompt += "\n## Current Context\n"
      prompt += "- Current time: #{context[:current_time].strftime('%A, %B
  %d, %Y at %H:%M %Z')}\n"
      prompt += "- Location: #{context[:location]}\n"

      # Add calendar events
      if context[:calendar].present?
        prompt += "\n## Upcoming Calendar Events\n"
        context[:calendar].each do |event|
          start_time = event["start"]
          # Simple replacement for display
          start_time = start_time.gsub(/, (\d{1,2}):(\d{2}) (AM|PM)/) do |match|
            hour = $1.to_i
            hour += 12 if $3 == "PM" && hour != 12
            hour = 0 if $3 == "AM" && hour == 12
            ", #{hour.to_s.rjust(2, '0')}:#{$2}"
          end

          end_time = event["start"]
          # Simple replacement for display
          end_time = end_time.gsub(/, (\d{1,2}):(\d{2}) (AM|PM)/) do |match|
            hour = $1.to_i
            hour += 12 if $3 == "PM" && hour != 12
            hour = 0 if $3 == "AM" && hour == 12
            ", #{hour.to_s.rjust(2, '0')}:#{$2}"
          end
          prompt += "- #{event["title"] || "Untitled"} on #{start_time}"
          prompt += " to #{event["end"]}" if event["end"]
          prompt += " at #{event["location"]}" if event["location"].present?
          prompt += " guests: "
          if event["guests"].any?
            event["guests"].each do |guest|
              prompt += "#{guest}, "
            end
          end
          prompt += "\n"
        end
      end

      prompt
    end

    private

    def self.fetch_calendar_events
      calendar = CalendarContext.first
      return [] unless calendar&.fetched_at&.> 1.hour.ago
      calendar.events
    end

    def self.fetch_recent_chats
      ChatMessage.order(created_at: :desc).limit(40).reverse
    end
  end
end
