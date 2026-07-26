Rails.application.routes.draw do
  resources :projects
  resource :session
  resources :passwords, param: :token

  # ===========================================================================
  # RAILS 8.1 — ACTIVE JOB CONTINUATIONS: Imports
  # ===========================================================================
  # GET  /imports/new   → form to start a new import
  # POST /imports        → create Import + enqueue ProcessImportJob
  # GET  /imports/:id   → live progress page with Turbo polling
  # GET  /imports        → list recent imports
  # ===========================================================================
  resources :imports, only: %i[index new create show]

  # ===========================================================================
  # RAILS 8.1 — STRUCTURED EVENT REPORTING: Events log
  # ===========================================================================
  # GET  /events       → display last 50 structured events from Solid Cache
  # DELETE /events     → clear the event log (via clear action)
  # ===========================================================================
  resources :events, only: %i[index] do
    collection do
      delete :clear
    end
  end

  # ===========================================================================
  # MISSION CONTROL JOBS — Web UI for Solid Queue
  # ===========================================================================
  # Available at /jobs — shows all queued, running, failed, finished jobs
  # Protected by a lambda constraint that checks the session cookie.
  # Only authenticated users (valid session_id cookie) can access /jobs.
  #
  # What you can do in Mission Control:
  #   - View all queues and worker status
  #   - See pending, in-progress, failed, finished jobs
  #   - Retry failed jobs manually
  #   - Discard stuck jobs
  #   - View recurring job schedules (from config/recurring.yml)
  # ===========================================================================
  constraints ->(request) {
    session_id = request.cookie_jar.signed[:session_id]
    session_id.present? && Session.exists?(id: session_id)
  } do
    mount MissionControl::Jobs::Engine => "/jobs"
  end

  # ===========================================================================
  # PWA — Progressive Web App routes
  # ===========================================================================
  # manifest.json → makes the app installable on mobile/desktop
  # service-worker.js → enables offline caching & background sync
  # ===========================================================================
  get "manifest"       => "rails/pwa#manifest",       as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # ===========================================================================
  # DASHBOARD — Rails 8 Features overview page
  # ===========================================================================
  get "dashboard" => "dashboard#index", as: :dashboard

  # Health check — used by Kamal proxy to verify the app is alive
  get "up" => "rails/health#show", as: :rails_health_check

  # Root
  root "projects#index"
end
