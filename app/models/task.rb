class Task < ApplicationRecord
  # ===========================================================================
  # RAILS 8.1 — DEPRECATED ASSOCIATIONS DEMO
  # ===========================================================================
  # Task belongs to a User. The association on User is marked deprecated
  # using the new Rails 8.1 `deprecated:` option on has_many.
  #
  # See app/models/user.rb for:
  #   has_many :tasks, deprecated: :notify
  #
  # This means calling user.tasks will emit a structured event via the
  # Rails 8.1 event reporter (Rails.event.notify) instead of silently succeeding.
  # The three modes are: :warn (default), :raise, :notify
  # ===========================================================================

  belongs_to :user

  validates :title, presence: true
end
