# ===========================================================================
# RAILS 8.1 — STRUCTURED EVENT REPORTING: Subscriber Registration
# ===========================================================================
# Rails.event is the new unified event bus introduced in Rails 8.1.
# Subscribers are registered here and receive all events emitted via:
#   Rails.event.notify("event.name", key: value, ...)
#
# The subscriber must implement #emit(event) — see:
#   app/subscribers/log_event_subscriber.rb
#
# You can register multiple subscribers (log to file AND send to Datadog, etc.)
# ===========================================================================
#
# ⚠️  FILTER BLOCK IS REQUIRED to prevent infinite recursion:
#
#   Rails 8.1 ships ActiveSupport::StructuredEventSubscriber which
#   automatically translates ALL ActiveSupport::Notifications events
#   (e.g. sql.active_record, process_action.action_controller, etc.)
#   into Rails.event.notify() calls.
#
#   Without a filter, our LogEventSubscriber#emit calls Rails.cache.read()
#   which issues a SQL query → ActiveSupport::Notifications fires
#   sql.active_record → StructuredEventSubscriber calls Rails.event.notify →
#   our subscriber emits → Rails.cache.read() → SQL → infinite loop →
#   SystemStackError (stack level too deep).
#
#   The fix: subscribe with a filter block that ONLY passes through events
#   we explicitly emit ourselves (project.*, import.*, stats.*, events.*).
#   Framework-generated events (active_record.*, action_controller.*, etc.)
#   are filtered out entirely.
# ===========================================================================

Rails.application.config.after_initialize do
  unless Rails.env.test?
    # Application-domain event name prefixes we care about.
    # Add more prefixes here as you add new event sources to the app.
    APP_EVENT_PREFIXES = %w[
      project.
      import.
      stats.
      events.
      deprecated_association.
    ].freeze

    Rails.event.subscribe(LogEventSubscriber.new) do |event|
      name = event[:name].to_s
      APP_EVENT_PREFIXES.any? { |prefix| name.start_with?(prefix) }
    end

    $stdout.puts "[EventReporter] LogEventSubscriber registered (filtering to app events only)"
  end
end
