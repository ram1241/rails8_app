class ArchiveProjectJob < ApplicationJob
  # ===========================================================================
  # SOLID QUEUE FEATURE DEMONSTRATION
  # ===========================================================================
  # Solid Queue is Rails 8's built-in database-backed job queue.
  # No Redis required — jobs are stored in queue.sqlite3
  #
  # Key features shown here:
  #   1. queue_as        — route jobs to specific queues
  #   2. retry_on        — automatic retry with exponential backoff
  #   3. discard_on      — discard job for certain error types
  #   4. priority        — lower number = higher priority
  #   5. before/after hooks — lifecycle callbacks
  # ===========================================================================

  # Route this job to the "default" queue (see config/queue.yml: queues: "*")
  queue_as :default

  # Solid Queue priority: lower number runs first (default: 0)
  # Use queue_with_priority in perform_later to set per-job priority
  # e.g. ArchiveProjectJob.set(priority: 10).perform_later(id)

  # Automatically retry on transient errors (e.g. DB lock timeout)
  # wait: :exponentially_longer → 3s, 18s, 83s, 258s ... (up to attempts limit)
  retry_on ActiveRecord::QueryAborted, wait: :exponentially_longer, attempts: 3

  # Permanently discard if the record is simply not found (no point retrying)
  discard_on ActiveRecord::RecordNotFound

  # ---------------------------------------------------------------------------
  # Lifecycle hooks (Solid Queue respects all ActiveJob callbacks)
  # ---------------------------------------------------------------------------
  before_perform do |job|
    Rails.logger.info "[SolidQueue] 🚀 Starting ArchiveProjectJob | project_id=#{job.arguments.first} | queue=#{job.queue_name}"
  end

  after_perform do |job|
    Rails.logger.info "[SolidQueue] ✅ Finished ArchiveProjectJob | project_id=#{job.arguments.first}"
  end

  # ---------------------------------------------------------------------------
  # perform — the actual job logic
  # ---------------------------------------------------------------------------
  def perform(project_id)
    project = Project.find(project_id) # raises RecordNotFound → discarded

    # Simulate work (in real app: send email, call API, update S3, etc.)
    Rails.logger.info "[SolidQueue] 📦 Archiving project: '#{project.title}' (id=#{project_id})"

    project.update!(archived: true)

    Rails.logger.info "[SolidQueue] ✅ Project '#{project.title}' archived successfully"
  rescue => e
    Rails.logger.error "[SolidQueue] ❌ Failed to archive project #{project_id}: #{e.message}"
    raise # re-raise so Solid Queue can retry / record the failure
  end
end
