class Import < ApplicationRecord
  # ===========================================================================
  # RAILS 8.1 — ACTIVE JOB CONTINUATIONS DEMO
  # ===========================================================================
  # Import represents a long-running CSV/data import operation.
  # The actual processing is done by ProcessImportJob which uses
  # ActiveJob::Continuable — Rails 8.1's built-in resumable job feature.
  #
  # Status lifecycle:
  #   pending   → job not yet started
  #   processing → job running (may be interrupted and resumed)
  #   completed  → all records processed successfully
  #   failed     → job failed after exhausting retries
  # ===========================================================================

  STATUSES = %w[pending processing completed failed].freeze

  validates :name,   presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :total_count, numericality: { greater_than: 0, allow_nil: false }

  scope :pending,    -> { where(status: "pending") }
  scope :processing, -> { where(status: "processing") }
  scope :completed,  -> { where(status: "completed") }
  scope :failed,     -> { where(status: "failed") }
  scope :recent,     -> { order(created_at: :desc).limit(10) }

  def progress_percentage
    return 0 if total_count.zero?
    ((processed_count.to_f / total_count) * 100).round(1)
  end

  def pending?    = status == "pending"
  def processing? = status == "processing"
  def completed?  = status == "completed"
  def failed?     = status == "failed"
  def finished?   = completed? || failed?
end
