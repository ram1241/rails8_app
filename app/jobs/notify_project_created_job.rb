class NotifyProjectCreatedJob < ApplicationJob
  # ===========================================================================
  # SOLID QUEUE — HIGH PRIORITY QUEUE DEMONSTRATION
  # ===========================================================================
  # This job runs on the "urgent" queue with higher priority than default.
  # In config/queue.yml, queues: "*" means all queues are processed.
  # You can dedicate workers to specific queues:
  #
  #   workers:
  #     - queues: "urgent"
  #       threads: 5
  #       polling_interval: 0.05   # check every 50ms
  #     - queues: "default,mailers"
  #       threads: 3
  #       polling_interval: 0.1
  # ===========================================================================

  queue_as :urgent

  retry_on StandardError, wait: 5.seconds, attempts: 2

  def perform(project_id)
    project = Project.find_by(id: project_id)
    return unless project

    # In a real app: send Slack notification, push notification, webhook, etc.
    Rails.logger.info "[SolidQueue:urgent] 🔔 NOTIFICATION: New project created!"
    Rails.logger.info "[SolidQueue:urgent]    Title       : #{project.title}"
    Rails.logger.info "[SolidQueue:urgent]    Description : #{project.description}"
    Rails.logger.info "[SolidQueue:urgent]    Created at  : #{project.created_at}"
  end
end
