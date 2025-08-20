# app/lib/ai/console_colors.rb
begin
  require "pastel"
rescue LoadError
  # pastel not available in production
end
require "zlib"

module Ai
  module ConsoleColors
    PALETTE = %i[bright_magenta bright_blue bright_green bright_yellow cyan].freeze
    module_function

    def pastel
      @pastel ||= defined?(Pastel) ? Pastel.new(enabled: $stdout.tty?) : NullPastel.new
    end

    class NullPastel
      def method_missing(method, *args)
        args.last.to_s # Return the text without coloring
      end
      
      def respond_to_missing?(method, include_private = false)
        true
      end
    end

    # Deterministic color for a given agent name (e.g., "llm_agent")
    def color_for(name)
      PALETTE[Zlib.crc32(name.to_s) % PALETTE.size]
    end

    def colored_badge(name)
      color = color_for(name)
      pastel.on_black.public_send(color).detach.(" #{name.upcase} ")
    end

    # Colored title text (used in the box title)
    def colored_title(name)
      pastel.public_send(color_for(name)).detach.(name.upcase)
    end

    def dim(s) = pastel.dim(s)
  end
end
