class CalendarSyncJob < ApplicationJob
 # This job is responsible for syncing calendar events.
 # It can be scheduled to run at specific intervals or triggered by specific events.

 # You can set the queue for this job if you have multiple queues configured.
 # For example, you might want to use a dedicated queue for calendar jobs.
 # Uncomment the line below to set a specific queue:
 #
 queue_as :default

 def perform
  puts "Running CalendarJob at #{Time.now}"
 end
end
