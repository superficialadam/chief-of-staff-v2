class BaseAgent
  def step!(_input)
    raise NotImplementedError
  end

  def name
    self.class.name.underscore  # "LlmAgent" -> "llm_agent"
  end
end
