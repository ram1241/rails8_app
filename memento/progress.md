# Progress — Rails 8 + Rails 8.1 Features Implementation + Kamal 2 Deployment

## Status: ✅ All Features Implemented & Verified

---

## Original Rails 8 Features (Session 1)

### Feature 1: Solid Queue — Background Jobs ✅
**Files changed:**
- [`app/jobs/archive_project_job.rb`](../app/jobs/archive_project_job.rb) — Enhanced with `retry_on`, `discard_on`, lifecycle hooks
- [`app/jobs/notify_project_created_job.rb`](../app/jobs/notify_project_created_job.rb) — NEW: high-priority urgent queue job
- [`app/models/project.rb`](../app/models/project.rb) — Enqueues both jobs on `after_create_commit`
- [`config/queue.yml`](../config/queue.yml) — Three workers: urgent, default, mailers queues

**How to test:** Create a project → check logs for `[SolidQueue]` entries → project auto-archives after 10s

---

### Feature 2: Solid Cache — Database-backed Caching ✅
**Files changed:**
- [`app/controllers/projects_controller.rb`](../app/controllers/projects_controller.rb) — `Rails.cache.fetch` for count stats + `expire_project_caches` on writes
- [`app/views/projects/index.html.erb`](../app/views/projects/index.html.erb) — Fragment caching with `<% cache project do %>`

**How to test:** Run `bin/rails dev:cache` to enable in development, then watch logs for `cache hit/miss`

---

### Feature 3: Solid Cable — Database-backed Action Cable ✅
**Files changed:**
- [`config/cable.yml`](../config/cable.yml) — Production uses `solid_cable` adapter
- [`app/channels/application_cable/connection.rb`](../app/channels/application_cable/connection.rb) — Authenticated by session cookie
- [`app/models/project.rb`](../app/models/project.rb) — `broadcast_append_to` on create, `broadcast_remove_to` on update

**How to test:** Open two browser tabs on `/projects` → create a project in one → appears in both live

---

### Feature 4: Recurring Jobs ✅
**Files changed:**
- [`app/jobs/project_stats_job.rb`](../app/jobs/project_stats_job.rb) — NEW: computes stats and writes to Solid Cache
- [`config/recurring.yml`](../config/recurring.yml) — Three recurring tasks: stats (every 5min dev/every 1min), cleanup (hourly), cache expire (midnight)

**How to test:** Start server with `SOLID_QUEUE_IN_PUMA=true`, check `/jobs` for recurring tasks tab

---

### Feature 5: Mission Control Jobs ✅
**Files changed:**
- [`config/routes.rb`](../config/routes.rb) — Mounted at `/jobs` with session cookie constraint (auth-protected)

**How to access:** Sign in first → visit `http://localhost:3000/jobs`

---

### Feature 6: PWA Support ✅
**Files changed:**
- [`config/routes.rb`](../config/routes.rb) — Enabled `pwa_manifest` and `pwa_service_worker` routes
- [`app/views/layouts/application.html.erb`](../app/views/layouts/application.html.erb) — Added manifest link tag + SW registration script
- [`app/views/pwa/manifest.json.erb`](../app/views/pwa/manifest.json.erb) — Full manifest with shortcuts, theme color, display mode
- [`app/views/pwa/service-worker.js`](../app/views/pwa/service-worker.js) — Cache-first + stale-while-revalidate strategy

**How to test:** Open Chrome DevTools → Application → Manifest (installable!), Service Workers (registered)

---

### Feature 7: Hotwire Turbo Streams ✅
**Files changed:**
- [`app/views/projects/index.html.erb`](../app/views/projects/index.html.erb) — `turbo_stream_from "projects_list"` subscription
- [`app/views/projects/_project.html.erb`](../app/views/projects/_project.html.erb) — Uses `dom_id`, shows live status badges
- [`app/models/project.rb`](../app/models/project.rb) — `broadcast_append_to` (create) + `broadcast_remove_to` (archive)

**How to test:** Create project → appears instantly (broadcast_append). 10s later it disappears (broadcast_remove after ArchiveProjectJob runs)

---

### Feature 8: Authentication (Rails 8 Generator) ✅
**Files changed:**
- [`app/views/layouts/application.html.erb`](../app/views/layouts/application.html.erb) — Nav bar with `Current.user.email_address`, sign out button
- [`app/controllers/dashboard_controller.rb`](../app/controllers/dashboard_controller.rb) — Shows active sessions list

**How to test:** Sign in → nav shows email, Dashboard shows all active sessions + IP + user agent

---

### Feature 9: Dashboard ✅
**Files:**
- [`app/controllers/dashboard_controller.rb`](../app/controllers/dashboard_controller.rb)
- [`app/views/dashboard/index.html.erb`](../app/views/dashboard/index.html.erb) — 14-card grid showing live status of every Rails 8 + 8.1 feature
- [`config/routes.rb`](../config/routes.rb) — `get "dashboard" => "dashboard#index"`

**URL:** `http://localhost:3000/dashboard` (requires login)

---

## Rails 8.1 New Features (Session 2)

### Feature A: Active Job Continuations ✅
**Rails 8.1 feature:** `include ActiveJob::Continuable` — multi-step resumable jobs with cursor that survive deploys and process restarts without losing progress.

**Files changed:**
- [`db/migrate/20260725065652_create_imports.rb`](../db/migrate/20260725065652_create_imports.rb) — Creates `imports` table (name, status enum, processed_count, total_count, error_message)
- [`app/models/import.rb`](../app/models/import.rb) — Import model with `pending/processing/completed/failed` enum, `recent` scope
- [`app/jobs/process_import_job.rb`](../app/jobs/process_import_job.rb) — `include ActiveJob::Continuable` with 3-step DSL + cursor tracking
- [`app/controllers/imports_controller.rb`](../app/controllers/imports_controller.rb) — index, new, create, show with Turbo polling
- [`app/views/imports/new.html.erb`](../app/views/imports/new.html.erb) — Start import form
- [`app/views/imports/show.html.erb`](../app/views/imports/show.html.erb) — Live progress via `<turbo-frame>` polling
- [`app/views/imports/index.html.erb`](../app/views/imports/index.html.erb) — Import history list
- [`config/routes.rb`](../config/routes.rb) — `resources :imports`

**How to test:** Visit `/imports/new` → fill in name + total records → submit → watch live progress polling via Turbo

**Key code:**
```ruby
class ProcessImportJob < ApplicationJob
  include ActiveJob::Continuable  # ✨ Rails 8.1

  def perform(import_id)
    @import = Import.find(import_id)
    step :validate     { @import.update!(status: :processing) }
    step :process_records do |step|
      @import.total_count.times do |i|
        next if i < (step.cursor || 0)
        @import.increment!(:processed_count)
        step.advance!(from: i + 1)
      end
    end
    step :finalize
  end
end
```

---

### Feature B: Structured Event Reporting ✅
**Rails 8.1 feature:** `Rails.event.notify(name, payload)` — unified structured event bus. Subscribers implement `#emit(event)` and receive all app events.

**Files changed:**
- [`app/subscribers/log_event_subscriber.rb`](../app/subscribers/log_event_subscriber.rb) — Receives events, logs to stdout via plain Logger (NOT Rails.logger — avoids SystemStackError), stores last 50 events in Solid Cache
- [`config/initializers/event_subscriber.rb`](../config/initializers/event_subscriber.rb) — Registers `LogEventSubscriber` with filter block (only `project.*`, `import.*`, `stats.*`, `deprecated_association.*`)
- [`app/models/project.rb`](../app/models/project.rb) — `Rails.event.notify("project.created", ...)` on `after_create_commit`, `"project.updated"` on `after_update_commit`
- [`app/controllers/events_controller.rb`](../app/controllers/events_controller.rb) — Reads events from Solid Cache
- [`app/views/events/index.html.erb`](../app/views/events/index.html.erb) — Events log page
- [`config/routes.rb`](../config/routes.rb) — `resources :events, only: [:index]`

**Critical fix — SystemStackError:**
`LogEventSubscriber` uses `PLAIN_LOGGER = ::Logger.new($stdout)` instead of `Rails.logger`. This prevents infinite recursion: `Rails.logger.info` → `BroadcastLogger#debug?` → `LogSubscriber#silenced?` → `Fanout#groups_for` → `StructuredEventSubscriber` → `Rails.event.notify` → `emit` → `Rails.logger.info` → loop.

The filter block in the initializer ensures only app-domain events (`project.*`, `import.*`, etc.) are processed — preventing `active_record.sql` events from triggering the subscriber.

**How to test:** Create a project → visit `/events` → see `project.created` event with payload

---

### Feature C: Markdown Rendering ✅
**Rails 8.1 feature:** `respond_to { format.md { render markdown: @object } }` — first-class Markdown response format. Object must implement `#to_markdown`.

**Files changed:**
- [`db/migrate/20260725065732_add_notes_to_projects.rb`](../db/migrate/20260725065732_add_notes_to_projects.rb) — Adds `notes:text` column to projects
- [`app/models/project.rb`](../app/models/project.rb) — `#to_markdown` method composing title, status, description, notes into Markdown document
- [`app/controllers/projects_controller.rb`](../app/controllers/projects_controller.rb) — `format.md { render markdown: @project }` in `show` action
- [`app/views/projects/_form.html.erb`](../app/views/projects/_form.html.erb) — Notes textarea with Markdown hint
- [`app/views/projects/show.html.erb`](../app/views/projects/show.html.erb) — "View as Markdown" link to `/projects/:id.md`

**How to test:** Create/edit a project with notes → visit `/projects/1.md` → browser shows raw Markdown with `text/markdown` Content-Type

**Note:** No `.md.erb` template is needed. `render markdown: @project` calls `@project.to_markdown` and returns the string directly as the response body.

---

### Feature D: Deprecated Associations ✅
**Rails 8.1 feature:** `has_many :tasks, deprecated: :notify` — marks an association as deprecated. Three modes: `:warn` (logs warning), `:raise` (raises error), `:notify` (instruments `AS::Notifications`).

**Files changed:**
- [`db/migrate/20260725065733_create_tasks.rb`](../db/migrate/20260725065733_create_tasks.rb) — Creates `tasks` table (user_id, title)
- [`app/models/task.rb`](../app/models/task.rb) — Task model `belongs_to :user`
- [`app/models/user.rb`](../app/models/user.rb) — `has_many :tasks, deprecated: :notify`
- [`config/initializers/deprecated_associations.rb`](../config/initializers/deprecated_associations.rb) — Sets `ActiveRecord::Associations::Deprecation.mode = :notify`, subscribes to `AS::Notifications("deprecated_association.active_record")` and bridges to `Rails.event.notify`

**How it works:**
1. `user.tasks` (or `User.includes(:tasks)`, etc.) triggers `ActiveRecord::Associations::Deprecation.report()`
2. With mode `:notify`, Rails instruments `"deprecated_association.active_record"` via `AS::Notifications`
3. Our initializer subscribes and bridges it to `Rails.event.notify("deprecated_association.active_record", ...)`
4. `LogEventSubscriber` captures it and stores in Solid Cache → visible at `/events`

**How to test:** The deprecation fires on any access to `user.tasks`. It appears in `/events` log and stdout.

---

## Bug Fixes Applied

### Dashboard ERB Error Fix ✅
**Error:** `undefined local variable or method 'project'` on `/dashboard`
**Cause:** The Solid Cache code example in the dashboard had literal `<% cache project do %>` ERB tags inside a `<div class="code-block">` — ERB was evaluating them as Ruby instead of displaying them as text.
**Fix:** Replaced with HTML entities: `<% cache project do %>` — now displays correctly as text.
**File:** [`app/views/dashboard/index.html.erb`](../app/views/dashboard/index.html.erb) — line ~130

---

## How to Start the App

```bash
# Start with Solid Queue running inside Puma (development)
SOLID_QUEUE_IN_PUMA=true bin/rails server

# Or start Solid Queue separately
bin/rails server &
bin/jobs start
```

## Key URLs

| URL | Purpose |
|-----|---------|
| `/` | Projects list (Turbo Streams live) |
| `/dashboard` | Rails 8 + 8.1 features status dashboard (14 cards) |
| `/projects/1.md` | View project as Markdown (Rails 8.1 feature) |
| `/imports` | Import history (Active Job Continuations) |
| `/imports/new` | Start a new resumable import job |
| `/events` | Structured events log (Rails.event.notify) |
| `/jobs` | Mission Control Jobs UI (requires login) |
| `/up` | Health check (used by Kamal) |
| `/manifest.json` | PWA manifest |
| `/service-worker.js` | PWA service worker |
| `/session/new` | Login page |

## Known Issues / Notes
- Fragment caching requires `bin/rails dev:cache` to be enabled in development
- Mission Control `/jobs` requires login (session cookie constraint)
- `SOLID_QUEUE_IN_PUMA=true` must be set to run jobs inside Puma in development
- `deprecated: :notify` emits via `AS::Notifications` not directly to `Rails.event` — our initializer bridges them
- `LogEventSubscriber` must use `PLAIN_LOGGER` (not `Rails.logger`) to prevent SystemStackError infinite recursion

## Verified Working (Rails runner checks)
- App boots cleanly: `Rails 8.1.3, Ruby 3.3.11`
- All models load: `Project(6), Import(0), Task(0), User(1)`
- `Rails.event.notify("project.created", ...)` → event stored in Solid Cache ✅
- `ActiveRecord::Associations::Deprecation.mode` = `:notify` ✅
- `Mime[:md]` = `text/markdown` ✅
- Dashboard data loads without error ✅

---

## Kamal 2 Deployment (Session 3)

### Platform: Oracle Cloud Always Free Tier ✅ (configured)
**$0/month forever** — Ampere A1 ARM64, 4 OCPU, 24 GB RAM, 200 GB storage

**Files changed:**
- [`config/deploy.yml`](../config/deploy.yml) — Kamal 2 config: ghcr.io registry, ARM64 build, SSL proxy, ubuntu SSH user, persistent SQLite volume
- [`.kamal/secrets`](../.kamal/secrets) — ghcr.io PAT-based auth via environment variables
- [`Dockerfile`](../Dockerfile) — ARM64-compatible, jemalloc path fixed for multiarch
- [`config/environments/production.rb`](../config/environments/production.rb) — `assume_ssl`, `force_ssl`, `/up` health check excluded from SSL redirect, mailer host from ENV
- [`memento/deploy.md`](deploy.md) — Complete step-by-step deployment guide

### Quick Deploy (after server provisioned):
```bash
# 1. Fill in config/deploy.yml: YOUR_GITHUB_USERNAME, YOUR_SERVER_IP, YOUR_DOMAIN
# 2. Export registry credentials:
export KAMAL_REGISTRY_USERNAME="your-github-username"
export KAMAL_REGISTRY_PASSWORD="ghp_your_pat_token"
# 3. First-time setup:
bin/kamal setup
# 4. Deploy:
bin/kamal deploy
```

### Status: ⏳ Awaiting server provisioning
Full guide: [`memento/deploy.md`](deploy.md)
