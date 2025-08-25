class ChatAgent < BaseAgent
  def initialize(system:)
    @system = system
  end

  def step!(input)
    # Prepare messages
    messages = [
      { role: :system, content: build_system_prompt },
      { role: :user, content: input }
    ]

    # save user message
    ChatMessage.create!(role: "user", content: input)

    response = call_llm(messages)

    # save asistant message
    ChatMessage.create!(role: "assistant", content: response)
    { agent: name, text: response }

  rescue => e
    Rails.logger.error "LlmAgent error: #{e.message}"
    { agent: name, text: "I encountered an error: #{e.message}" }
  end


  private

  def build_system_prompt
    history = get_chat_history(max_messages: 100)
    prompt = @system.dup # how do I join in Ruby?
    prompt += "Recent chat history:\n"
    history.each do |msg|
      prompt += "#{msg.created_at.strftime('%H:%M:%S')}: #{msg.role.capitalize}: #{msg.content}\n"
    end
    prompt
  end

  def call_llm(messages)
    Rails.logger.info "Making OpenAI API call"
    start_time = Time.current
    response = OPENAI.chat.completions.create(
      model: OPENAI_MODEL,
      messages: messages
    )
    api_duration = Time.current - start_time
    Rails.logger.info "OpenAI API call completed in #{(api_duration * 1000).round}ms"

    response.choices[0].message.content
  end


  def get_chat_history(max_messages:)
    ChatMessage.order(created_at: :desc).limit(max_messages).reverse
  end
end
