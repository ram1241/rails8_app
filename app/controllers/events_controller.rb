class EventsController < ApplicationController
  # ===========================================================================
  # RAILS 8.1 — STRUCTURED EVENT REPORTING DEMO
  # ===========================================================================
  # Displays the last 50 structured events stored in Solid Cache by
  # LogEventSubscriber (app/subscribers/log_event_subscriber.rb).
  #
  # Events are emitted throughout the app via Rails.event.notify():
  #   - project.created / project.updated  (app/models/project.rb)
  #   - import.started / import.progress / import.completed (app/jobs/process_import_job.rb)
  #   - import.enqueued (app/controllers/imports_controller.rb)
  #   - stats.computed (app/jobs/project_stats_job.rb)
  #   - deprecated_association.called (auto-emitted by Rails 8.1 for deprecated: :notify)
  # ===========================================================================

  def index
    @events = Rails.cache.read("structured_events/recent") || []

    # Emit a structured event for this page view itself (meta demo!)
    Rails.event.notify(
      "events.viewed",
      user_id: Current.user&.id,
      count:   @events.size
    )
  end

  def clear
    Rails.cache.delete("structured_events/recent")
    redirect_to events_path, notice: "Event log cleared."
  end
end
