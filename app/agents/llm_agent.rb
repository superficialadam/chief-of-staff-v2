class LlmAgent < BaseAgent
  def initialize(system:)
    @system = system
  end

  def step!(input)
    resp = OPENAI.responses.create(
      model: OPENAI_MODEL.to_sym,
      input: [
        { role: :system, content: @system },
        { role: :user,   content: input }
      ]
    )
    { agent: name, text: resp.output_text }
  end
end
