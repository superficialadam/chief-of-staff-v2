require "openai"
OPENAI = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))  # will raise if missing
OPENAI_MODEL = "gpt-5"
