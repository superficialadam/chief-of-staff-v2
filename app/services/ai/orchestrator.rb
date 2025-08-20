# app/services/ai/orchestrator.rb
module Ai
  class Orchestrator
    def initialize(agent: default_agent)
      @agent = agent
      @booted = false
    end

    def run!(input)
      boot_once!
      @agent.step!(input)
    end
    
    def run_with_progress!(input, &block)
      boot_once!
      @agent.step_with_progress!(input, &block)
    end

    def health
      boot_once!
      { mcp: Ai::McpManager.instance.status_report }
    end

    private

    def default_agent
      system_prompt = File.read(Rails.root.join("prompts/agents/assistant.md"))
      LlmAgent.new(system: system_prompt, mcp_manager: Ai::McpManager.instance)
    end

    def boot_once!
      return if @booted
      Ai::McpManager.instance.boot!(strict: false)  # sync boot; no crash
      @booted = true
    end
  end
end
