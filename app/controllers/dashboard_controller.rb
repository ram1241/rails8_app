class DashboardController < ApplicationController
  # ===========================================================================
  # DASHBOARD — Rails 8 Features Status Overview
  # ===========================================================================
  # Shows live status of all Rails 8 built-in features in one page.
  # Uses Solid Cache to store and retrieve stats computed by ProjectStatsJob.
  # ===========================================================================

  def index
    # -------------------------------------------------------------------------
    # SOLID CACHE — read stats written by the recurring ProjectStatsJob
    # Falls back to a live DB query if the cache hasn't been populated yet
    # -------------------------------------------------------------------------
    @cached_stats = Rails.cache.read("project_stats/latest") || compute_stats_live

    # -------------------------------------------------------------------------
    # SOLID QUEUE — read queue depth from the Solid Queue tables
    # SolidQueue::Job stores all jobs; we read counts per status
    # -------------------------------------------------------------------------
    @queue_stats = {
      pending:   SolidQueue::Job.where(finished_at: nil).count,
      finished:  SolidQueue::Job.where.not(finished_at: nil).count,
      failed:    SolidQueue::FailedExecution.count,
      recurring: SolidQueue::RecurringTask.count
    }

    # -------------------------------------------------------------------------
    # AUTHENTICATION — current session info
    # Current.session is set by the Authentication concern
    # -------------------------------------------------------------------------
    @current_session_info = {
      user:       Current.user&.email_address,
      ip:         Current.session&.ip_address,
      user_agent: Current.session&.user_agent,
      created_at: Current.session&.created_at,
      all_sessions: Current.user&.sessions&.order(created_at: :desc)
    }

    # -------------------------------------------------------------------------
    # SOLID CABLE — check adapter in use
    # -------------------------------------------------------------------------
    @cable_adapter = ActionCable.server.config.cable["adapter"]

    # -------------------------------------------------------------------------
    # Solid Cache — show whether cache is live
    # -------------------------------------------------------------------------
    @cache_store = Rails.cache.class.name

    # -------------------------------------------------------------------------
    # RAILS 8.1 — ACTIVE JOB CONTINUATIONS: Import stats for dashboard card
    # -------------------------------------------------------------------------
    @import_stats = {
      total:      Import.count,
      pending:    Import.pending.count,
      processing: Import.processing.count,
      completed:  Import.completed.count,
      failed:     Import.failed.count,
      recent:     Import.recent.first(3)
    }

    # -------------------------------------------------------------------------
    # RAILS 8.1 — STRUCTURED EVENT REPORTING: Recent events count for dashboard
    # -------------------------------------------------------------------------
    @structured_events = Rails.cache.read("structured_events/recent") || []

    # -------------------------------------------------------------------------
    # RAILS 8.1 — DEPRECATED ASSOCIATIONS: Task count for dashboard demo
    # -------------------------------------------------------------------------
    @tasks_count = Task.count
  end

  private

  def compute_stats_live
    {
      total:        Project.count,
      active:       Project.where(archived: false).count,
      archived:     Project.where(archived: true).count,
      ratio:        Project.count > 0 ? (Project.where(archived: true).count.to_f / Project.count * 100).round(1) : 0,
      generated_at: Time.current.iso8601,
      source:       "live DB query (cache not yet populated)"
    }
  end
end
