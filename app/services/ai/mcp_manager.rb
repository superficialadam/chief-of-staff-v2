# app/services/ai/mcp_manager.rb
require "json"
require "singleton"
require "mcp_client"

module Ai
  class McpManager
    include Singleton

    attr_reader :client, :booted

    def initialize
      @booted = false
      @client = nil
      @server_configs = []
    end

    def boot!(strict: false)
      return if @booted
      
      # Skip MCP in production for now
      if Rails.env.production?
        Rails.logger.info "MCP Manager disabled in production"
        @booted = true
        return
      end
      
      load_config
      
      begin
        @client = MCPClient.create_client(
          mcp_server_configs: @server_configs,
          logger: Rails.logger
        )
        
        @client.connect if @client.respond_to?(:connect)
        
        @booted = true
        Rails.logger.info "MCP Manager booted successfully with #{@server_configs.size} server(s)"
      rescue => e
        Rails.logger.error "MCP boot failed: #{e.message}"
        raise if strict
        @booted = false
      end
    end

    def status_report
      return { status: "not_booted" } unless @booted && @client
      
      tools = list_tools
      {
        status: "connected",
        tools_count: tools.size,
        tools: tools.map { |t| t.name }
      }
    rescue => e
      { status: "error", error: e.message }
    end

    def list_tools
      return [] unless @booted && @client
      @client.list_tools || []
    end

    def openai_tools
      return [] if Rails.env.production?  # MCP disabled in production
      return [] unless @booted && @client
      @client.to_openai_tools || []
    end

    def anthropic_tools
      return [] if Rails.env.production?  # MCP disabled in production
      return [] unless @booted && @client
      @client.to_anthropic_tools || []
    end

    def call_tool(name, parameters = {})
      if Rails.env.production?
        return { error: "MCP disabled in production" }
      end
      raise "MCP Manager not booted" unless @booted && @client
      
      result = @client.call_tool(name, parameters)
      
      # Handle different result formats from MCP
      if result.is_a?(Hash)
        result[:content] || result["content"] || result
      else
        result
      end
    rescue => e
      Rails.logger.error "MCP tool call failed: #{e.message}"
      { error: e.message }
    end

    def cleanup
      @client&.cleanup if @client&.respond_to?(:cleanup)
      @booted = false
      @client = nil
    end

    private

    def load_config
      path = Rails.root.join("config/mcp.json")
      raise "Missing config/mcp.json" unless File.exist?(path)
      
      config = JSON.parse(File.read(path))
      @server_configs = []
      
      config.fetch("servers", []).each do |server|
        if server["type"] == "stdio" || server["command"]
          # Stdio server configuration
          command_parts = build_command(server)
          env = expand_env(server["env"] || {})
          
          @server_configs << MCPClient.stdio_config(
            command: command_parts.join(" "),
            env: env,
            name: server["alias"]
          )
        elsif server["type"] == "sse" || (server["url"] && server["url"].include?("/sse"))
          # SSE server configuration
          @server_configs << MCPClient.sse_config(
            base_url: server["url"],
            headers: server["headers"] || {},
            name: server["alias"]
          )
        elsif server["type"] == "http" || server["url"]
          # HTTP server configuration
          @server_configs << MCPClient.http_config(
            base_url: server["url"],
            endpoint: server["endpoint"] || "/rpc",
            headers: server["headers"] || {},
            name: server["alias"]
          )
        end
      end
    end

    def build_command(server)
      parts = []
      parts << server["command"]
      parts.concat(Array(server["args"])) if server["args"]
      parts
    end

    def expand_env(hash)
      hash.transform_values do |v|
        case v
        when String
          if v.start_with?("env:")
            key = v.split(":", 2).last
            ENV.fetch(key) { raise "Missing ENV[#{key}] for MCP server" }
          elsif v.start_with?("file:")
            rel = v.split(":", 2).last
            path = Rails.root.join(rel)
            raise "Missing credential file #{path}" unless File.exist?(path)
            path.to_s
          elsif v.start_with?("/")
            # Handle absolute paths
            raise "Missing credential file #{v}" unless File.exist?(v)
            v
          else
            v
          end
        else
          v
        end
      end
    end
  end
end