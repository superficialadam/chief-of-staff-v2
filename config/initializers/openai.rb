require "openai"

# Only initialize OpenAI client if API key is available (not during asset precompilation)
if ENV["OPENAI_API_KEY"].present?
  OPENAI = OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"])
else
  OPENAI = nil  # Will be initialized at runtime with proper environment
end

OPENAI_MODEL = "gpt-5"
