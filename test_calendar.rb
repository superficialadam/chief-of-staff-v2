#!/usr/bin/env ruby
# Test calendar query

require_relative "config/environment"

orchestrator = Ai::Orchestrator.new

# Test queries
queries = [
  "What events do I have tomorrow?",
  "List my calendars"
]

queries.each do |query|
  puts "\n" + "="*50
  puts "QUERY: #{query}"
  puts "="*50
  
  result = orchestrator.run!(query)
  puts "\nRESPONSE:"
  puts result[:text]
  puts "\n"
end