# ===========================================================================
# RAILS 8.1 — DEPRECATED ASSOCIATIONS CONFIGURATION
# ===========================================================================
# Rails 8.1 adds a `deprecated:` option to has_many, has_one, belongs_to.
# When a deprecated association is accessed, Rails can:
#
#   :warn    → logs a warning via ActiveRecord::Base.logger (default)
#   :raise   → raises ActiveRecord::DeprecatedAssociationError
#   :notify  → instruments "deprecated_association.active_record" via
#               ActiveSupport::Notifications (does NOT auto-bridge to Rails.event)
#
# We set mode to :notify so we can bridge the AS::Notifications event into
# our Rails.event bus via LogEventSubscriber for the structured events log.
#
# Usage in model:
#   has_many :tasks, deprecated: :notify
#
# Result: accessing user.tasks emits "deprecated_association.active_record"
# via AS::Notifications → our bridge converts it to:
#   Rails.event.notify("deprecated_association.active_record", ...)
# which LogEventSubscriber captures and stores in Solid Cache.
# ===========================================================================

Rails.application.config.after_initialize do
  unless Rails.env.test?
    # Set the global deprecated associations mode to :notify
    # This affects all models that use `deprecated: :notify`
    ActiveRecord::Associations::Deprecation.mode = :notify

    # ---------------------------------------------------------------------------
    # Bridge ActiveSupport::Notifications → Rails.event
    #
    # When mode is :notify, ActiveRecord fires:
    #   ActiveSupport::Notifications.instrument(
    #     "deprecated_association.active_record",
    #     reflection:, message:, location:
    #   )
    #
    # We subscribe and forward it to Rails.event.notify() so it appears in
    # our structured events log (/events page and Solid Cache).
    # ---------------------------------------------------------------------------
    ActiveSupport::Notifications.subscribe("deprecated_association.active_record") do |name, _start, _finish, _id, payload|
      reflection = payload[:reflection]
      association_name = reflection ? "#{reflection.active_record}##{reflection.name}" : "unknown"

      Rails.event.notify(
        "deprecated_association.active_record",
        association:  association_name,
        message:      payload[:message].to_s.truncate(200),
        location:     payload[:location]&.to_s
      )
    rescue => e
      # Silently rescue — never let a subscriber crash the request
      $stdout.puts "[DeprecatedAssociation] Failed to emit event: #{e.message}"
    end

    $stdout.puts "[DeprecatedAssociation] mode=:notify, bridge to Rails.event registered"
  end
end
