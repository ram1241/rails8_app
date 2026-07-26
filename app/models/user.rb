class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  # ===========================================================================
  # RAILS 8.1 — DEPRECATED ASSOCIATIONS
  # ===========================================================================
  # The `deprecated:` option marks this association as deprecated.
  # Three reporting modes are available:
  #   deprecated: true     → same as :warn (default)
  #   deprecated: :warn    → logs a warning to Rails.logger
  #   deprecated: :raise   → raises ActiveRecord::DeprecatedAssociationError
  #   deprecated: :notify  → emits a structured Rails.event notification
  #
  # Triggers on: user.tasks, user.tasks=, user.preload(:tasks),
  #              nested_attributes_for :tasks, includes(:tasks), etc.
  #
  # This models a real-world scenario where tasks are being migrated to
  # a dedicated service and the old association is being phased out.
  # ===========================================================================
  has_many :tasks, deprecated: :notify

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
