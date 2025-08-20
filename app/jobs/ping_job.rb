class PingJob < ApplicationJob
  queue_as :default

  def perform(message = "pong")
    Rails.logger.info "[PingJob] ran with message: #{message}"
  end
end
