# ===========================================================================
# RAILS 8.1 — STRUCTURED EVENT REPORTING: Subscriber
# ===========================================================================
# Subscribers implement #emit(event) and receive every Rails.event.notify call.
#
# The `event` hash contains:
#   event[:name]            → "project.created", "import.started", etc.
#   event[:payload]         → the arbitrary hash passed to notify()
#   event[:tags]            → hash of tag strings (from Rails.event.tagged)
#   event[:context]         → hash set via Rails.event.set_context(...)
#   event[:source_location] → { filepath:, lineno:, label: } — auto-captured by Rails
#   event[:timestamp]       → nanosecond monotonic clock value
#
# ⚠️  IMPORTANT — WHY WE USE A PLAIN LOGGER HERE (NOT Rails.logger):
#
#   Rails.logger is an ActiveSupport::BroadcastLogger. When we call
#   Rails.logger.info(...), the BroadcastLogger checks debug?/info? on each
#   sub-logger. That check goes through ActiveSupport::LogSubscriber#silenced?,
#   which calls Notifications::Fanout#groups_for. In Rails 8.1, some part of
#   that fanout chain triggers another Rails.event.notify call — which calls
#   our emit method again — causing infinite recursion (SystemStackError).
#
#   Solution: write log output through a plain Ruby Logger that is completely
#   independent of the ActiveSupport::Notifications/BroadcastLogger stack.
#   We share one instance per-process (class-level @logger).
#
# This subscriber does two things:
#   1. Writes a human-readable line to $stdout via the plain logger
#   2. Stores the last 50 events in Solid Cache for the /events dashboard page
# ===========================================================================
class LogEventSubscriber
  MAX_EVENTS = 50

  # ---------------------------------------------------------------------------
  # Class-level plain logger — bypasses Rails.logger / BroadcastLogger entirely.
  # This is the key fix for the SystemStackError (stack level too deep) that
  # occurs when Rails.logger.info is called from within a Rails.event subscriber.
  # ---------------------------------------------------------------------------
  PLAIN_LOGGER = ::Logger.new($stdout).tap do |l|
    l.formatter = proc { |_sev, _time, _prog, msg| "#{msg}\n" }
  end

  def emit(event)
    log_event(event)
    store_event(event)
  end

  private

  def log_event(event)
    payload_str = begin
      event[:payload].map { |k, v| "#{k}=#{v.inspect}" }.join(" ")
    rescue
      event[:payload].inspect
    end

    source = event[:source_location]
    location = source ? "#{File.basename(source[:filepath].to_s)}:#{source[:lineno]}" : "unknown"
    occurred = Time.now.iso8601

    PLAIN_LOGGER.info(
      "[StructuredEvent] #{event[:name]} | #{payload_str} | at #{location} | #{occurred}"
    )
  end

  def store_event(event)
    events = Rails.cache.read("structured_events/recent") || []

    events.unshift({
      name:            event[:name].to_s,
      payload:         safe_payload(event[:payload]),
      tags:            event[:tags],
      context:         event[:context],
      source_location: event[:source_location],
      occurred_at:     Time.now.iso8601
    })

    # Keep only the most recent MAX_EVENTS
    events = events.first(MAX_EVENTS)

    Rails.cache.write("structured_events/recent", events, expires_in: 24.hours)
  rescue => e
    # Use PLAIN_LOGGER here too — same reason as above
    PLAIN_LOGGER.warn("[StructuredEvent] Failed to store event '#{event[:name]}': #{e.message}")
  end

  # ---------------------------------------------------------------------------
  # Safely serialize the payload for cache storage.
  # Handles both Hash payloads (from notify("name", key: val)) and
  # object payloads (from notify(EventObject.new(...))).
  # ---------------------------------------------------------------------------
  def safe_payload(payload)
    case payload
    when Hash
      payload.transform_values { |v| v.is_a?(String) ? v.truncate(200) : v rescue v.inspect }
    when NilClass
      {}
    else
      { raw: payload.inspect.truncate(200) }
    end
  rescue
    {}
  end
end
