class ProjectStatsJob < ApplicationJob
  # ===========================================================================
  # SOLID QUEUE — RECURRING JOB DEMONSTRATION
  # ===========================================================================
  # This job is scheduled to run automatically on a recurring basis.
  # The schedule is defined in config/recurring.yml — no cron daemon needed.
  # Solid Queue's dispatcher reads recurring.yml and enqueues this job
  # at the configured interval automatically.
  #
  # How recurring works:
  #   1. Solid Queue dispatcher boots and reads config/recurring.yml
  #   2. It creates a SolidQueue::RecurringTask record in the DB
  #   3. The dispatcher enqueues this job at the configured schedule
  #   4. Workers pick it up and execute perform()
  #
  # You can see recurring tasks in Mission Control at /jobs
  # ===========================================================================

  queue_as :default

  retry_on StandardError, wait: 30.seconds, attempts: 2

  def perform
    total    = Project.count
    active   = Project.where(archived: false).count
    archived = Project.where(archived: true).count

    stats = {
      total:      total,
      active:     active,
      archived:   archived,
      ratio:      total > 0 ? (archived.to_f / total * 100).round(1) : 0,
      generated_at: Time.current.iso8601
    }

    # Store the latest stats in Solid Cache (expires in 1 hour)
    # The dashboard controller reads this cached value
    Rails.cache.write("project_stats/latest", stats, expires_in: 1.hour)

    Rails.logger.info "[RecurringJob] 📊 ProjectStatsJob completed:"
    Rails.logger.info "[RecurringJob]    Total    : #{stats[:total]}"
    Rails.logger.info "[RecurringJob]    Active   : #{stats[:active]}"
    Rails.logger.info "[RecurringJob]    Archived : #{stats[:archived]}"
    Rails.logger.info "[RecurringJob]    Archive% : #{stats[:ratio]}%"
    Rails.logger.info "[RecurringJob]    At       : #{stats[:generated_at]}"

    # =========================================================================
    # RAILS 8.1 — STRUCTURED EVENT REPORTING
    # =========================================================================
    # Emit a machine-readable structured event so subscribers can react to it.
    # LogEventSubscriber stores this in Solid Cache → visible at /events.
    #
    # This demonstrates using Rails.event.notify in a recurring background job —
    # useful for triggering metrics pipelines, alerting, or audit trails.
    # =========================================================================
    Rails.event.notify(
      "stats.computed",
      total:    stats[:total],
      active:   stats[:active],
      archived: stats[:archived],
      ratio:    stats[:ratio],
      source:   "ProjectStatsJob"
    )
  end
end
