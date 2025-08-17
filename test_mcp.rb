#!/usr/bin/env ruby
# Test MCP Manager configuration

require_relative "config/environment"

puts "Testing MCP Manager..."
puts "-" * 50

manager = Ai::McpManager.instance

begin
  puts "Booting MCP servers..."
  manager.boot!(strict: false)
  
  sleep 2 # Give servers time to initialize
  
  puts "\nStatus Report:"
  status = manager.status_report
  puts JSON.pretty_generate(status)
  
  puts "\nAvailable Tools:"
  tools = manager.list_tools
  if tools.any?
    tools.each do |tool|
      puts "  - #{tool.name}: #{tool.description}"
    end
  else
    puts "  No tools available"
  end
  
  puts "\nOpenAI Tools Format:"
  openai_tools = manager.openai_tools
  puts "  Found #{openai_tools.size} tools for OpenAI"
  
  # Test a simple tool if filesystem is available
  if tools.any? { |t| t.name.include?("read") }
    puts "\nTesting file read tool..."
    result = manager.call_tool("read_file", { path: "README.md" })
    puts "  Read file successful: #{result.is_a?(Hash) ? result.keys : 'yes'}"
  end
  
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
ensure
  puts "\nCleaning up..."
  manager.cleanup
end

puts "\nTest complete!"