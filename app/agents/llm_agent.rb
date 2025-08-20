class LlmAgent < BaseAgent
  def initialize(system:, mcp_manager: nil)
    @system = system
    @mcp_manager = mcp_manager || Ai::McpManager.instance
  end

  def step!(input)
    # Boot MCP if not already booted
    @mcp_manager.boot!(strict: false) unless @mcp_manager.booted
    
    # Get available MCP tools
    tools = @mcp_manager.openai_tools
    
    # Prepare messages
    messages = [
      { role: :system, content: build_system_prompt },
      { role: :user, content: input }
    ]
    
    # Call OpenAI with or without tools
    response = if tools.any?
      call_with_tools(messages, tools)
    else
      call_without_tools(messages)
    end
    
    { agent: name, text: response }
  rescue => e
    Rails.logger.error "LlmAgent error: #{e.message}"
    { agent: name, text: "I encountered an error: #{e.message}" }
  end
  
  def step_with_progress!(input, &progress_callback)
    # Boot MCP if not already booted
    @mcp_manager.boot!(strict: false) unless @mcp_manager.booted
    
    # Get available MCP tools
    tools = @mcp_manager.openai_tools
    
    # Prepare messages
    messages = [
      { role: :system, content: build_system_prompt },
      { role: :user, content: input }
    ]
    
    # Store the progress callback
    @progress_callback = progress_callback
    
    # Call OpenAI with or without tools
    response = if tools.any?
      call_with_tools(messages, tools)
    else
      call_without_tools(messages)
    end
    
    { agent: name, text: response }
  rescue => e
    Rails.logger.error "LlmAgent error: #{e.message}"
    { agent: name, text: "I encountered an error: #{e.message}" }
  ensure
    @progress_callback = nil
  end
  
  private
  
  def build_system_prompt
    prompt = @system.dup
    
    # Add tool descriptions if available
    if @mcp_manager.booted
      tools = @mcp_manager.list_tools
      if tools.any?
        prompt += "\n\n## Available Tools\n"
        prompt += "You have access to the following tools:\n"
        tools.each do |tool|
          prompt += "- #{tool.name}: #{tool.description}\n"
        end
        prompt += "\nUse these tools when appropriate to help answer questions or perform tasks."
      end
    end
    
    prompt
  end
  
  def call_with_tools(messages, tools)
    max_iterations = 5
    iteration = 0
    
    while iteration < max_iterations
      iteration += 1
      
      # Send iteration event if callback is present
      @progress_callback&.call(:iteration, { number: iteration, max: max_iterations })
      
      # Make the API call
      Rails.logger.info "Making OpenAI API call (iteration #{iteration})..."
      start_time = Time.current
      response = OPENAI.chat.completions.create(
        model: OPENAI_MODEL,
        messages: messages,
        tools: tools,
        tool_choice: "auto"
      )
      api_duration = Time.current - start_time
      Rails.logger.info "OpenAI API call completed in #{(api_duration * 1000).round}ms"
      
      message = response.choices[0].message
      
      # If no tool calls, we have our final answer
      unless message.tool_calls
        return message.content || "I couldn't generate a response."
      end
      
      # Log tool calls for debugging
      Rails.logger.info "Executing #{message.tool_calls.length} tool calls (iteration #{iteration})"
      
      # Execute tool calls
      tool_results = execute_tool_calls(message.tool_calls)
      
      # Add the assistant's message with tool calls
      messages << {
        role: :assistant,
        content: message.content,
        tool_calls: message.tool_calls.map do |tc|
          {
            id: tc.id,
            type: tc.type,
            function: {
              name: tc.function.name,
              arguments: tc.function.arguments
            }
          }
        end
      }
      
      # Add tool results as messages
      tool_results.each do |result|
        messages << {
          role: :tool,
          tool_call_id: result[:id],
          content: result[:content].to_json
        }
      end
      
      # Continue the loop to see if more tool calls are needed
    end
    
    # If we've exhausted iterations, make one final call without tools
    Rails.logger.warn "Reached max tool iterations, making final call"
    start_time = Time.current
    final_response = OPENAI.chat.completions.create(
      model: OPENAI_MODEL,
      messages: messages
    )
    api_duration = Time.current - start_time
    Rails.logger.info "Final OpenAI API call completed in #{(api_duration * 1000).round}ms"
    
    final_response.choices[0].message.content || "I completed the tool calls but couldn't generate a final response."
  end
  
  def call_without_tools(messages)
    Rails.logger.info "Making OpenAI API call (no tools)..."
    start_time = Time.current
    response = OPENAI.chat.completions.create(
      model: OPENAI_MODEL,
      messages: messages
    )
    api_duration = Time.current - start_time
    Rails.logger.info "OpenAI API call (no tools) completed in #{(api_duration * 1000).round}ms"
    
    response.choices[0].message.content
  end
  
  def execute_tool_calls(tool_calls)
    tool_calls.map do |tool_call|
      begin
        # Parse the arguments
        args = JSON.parse(tool_call.function.arguments)
        
        Rails.logger.info "Calling tool: #{tool_call.function.name} with args: #{args.inspect}"
        
        # Send tool_start event if callback is present
        @progress_callback&.call(:tool_start, { 
          name: tool_call.function.name, 
          args: args 
        })
        
        # Call the tool through MCP manager
        result = @mcp_manager.call_tool(tool_call.function.name, args)
        
        Rails.logger.info "Tool result: #{result.class} - #{result.is_a?(String) ? result[0..100] : result.inspect[0..200]}"
        
        # Send tool_complete event if callback is present
        @progress_callback&.call(:tool_complete, { 
          name: tool_call.function.name,
          success: true
        })
        
        {
          id: tool_call.id,
          content: result
        }
      rescue => e
        Rails.logger.error "Tool execution error for #{tool_call.function.name}: #{e.message}"
        Rails.logger.error e.backtrace.first(3).join("\n")
        
        # Send tool_complete event with error if callback is present
        @progress_callback&.call(:tool_complete, { 
          name: tool_call.function.name,
          success: false,
          error: e.message
        })
        
        {
          id: tool_call.id,
          content: { error: "Tool execution failed: #{e.message}" }
        }
      end
    end
  end
end