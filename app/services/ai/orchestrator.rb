module Ai
  class Orchestrator
    def initialize(agent: default_agent)
      @agent = agent
    end

    def run!(input)
      @agent.step!(input)  # returns { agent:, text: }
    end

    private

    def default_agent
      system_prompt = File.read(Rails.root.join("prompts/agents/assistant.md"))
      LlmAgent.new(system: system_prompt)
    end
  end
end
