class ProcessImportJob < ApplicationJob
  # ===========================================================================
  # RAILS 8.1 — ACTIVE JOB CONTINUATIONS
  # ===========================================================================
  # include ActiveJob::Continuable enables this job to be interrupted and
  # resumed without losing progress. This is the flagship Rails 8.1 feature.
  #
  # How it works:
  #   1. The job is broken into named `step` blocks
  #   2. Each step can use a `cursor` to track progress within the step
  #   3. When the job is interrupted (deploy, memory limit, timeout):
  #        - The current step name and cursor are persisted to the queue DB
  #        - The job is re-enqueued automatically
  #        - On resume: completed steps are skipped, in-progress step
  #          resumes from the last saved cursor position
  #
  # Checkpoint semantics:
  #   step.advance!(from: record.id)  → saves cursor = record.id, then checks
  #                                     if the queue adapter wants to stop.
  #                                     If stopping? → persists state, requeues.
  #   step.checkpoint!                → forces a stop check without advancing
  #   step.set!(value)                → sets cursor to arbitrary value
  #
  # Queue adapter support for stopping?:
  #   The adapter must implement #stopping? for live interruption.
  #   Solid Queue support is planned; currently Test adapter + Sidekiq support it.
  #   Even without stopping?, cursors still resume correctly after crashes.
  # ===========================================================================
  include ActiveJob::Continuable

  queue_as :default

  retry_on StandardError, wait: 30.seconds, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  # ---------------------------------------------------------------------------
  # perform — define the multi-step continuation flow
  # Code OUTSIDE steps runs on every resume (load state, set instance vars)
  # Steps are SKIPPED if already completed; cursor resumes mid-step
  # ---------------------------------------------------------------------------
  def perform(import_id)
    # This runs on every execution (including resumes) — must be idempotent
    @import = Import.find(import_id)

    Rails.logger.info "[Continuable] Starting/resuming ProcessImportJob for import ##{import_id} (#{@import.name})"

    # -------------------------------------------------------------------------
    # STEP 1: validate
    # Block format — no cursor needed, this step is all-or-nothing
    # -------------------------------------------------------------------------
    step :validate do
      Rails.logger.info "[Continuable] Step: validate — import ##{@import.id}"
      @import.update!(status: "processing")

      # Emit structured event (Rails 8.1 Feature B)
      Rails.event.notify(
        "import.started",
        import_id: @import.id,
        name:      @import.name,
        total:     @import.total_count
      )

      raise ArgumentError, "Import has no records to process" if @import.total_count.zero?
    end

    # -------------------------------------------------------------------------
    # STEP 2: process_records (with cursor — the key Continuable feature)
    # Uses step.cursor to know where to resume after interruption.
    # step.advance!(from: record_number) saves the cursor and checks stopping?
    # -------------------------------------------------------------------------
    step :process_records do |step|
      Rails.logger.info "[Continuable] Step: process_records — resuming from cursor=#{step.cursor.inspect}"

      # Simulate processing records numbered 1..total_count
      # In a real app: CSV rows, DB records, API pages, S3 objects, etc.
      start_from = step.cursor || 0

      (start_from...@import.total_count).each do |i|
        record_number = i + 1

        # Simulate work per record (e.g. parse CSV row, create Project, etc.)
        simulate_record_processing(record_number)

        # Update progress in DB every 10 records (batching DB writes)
        if record_number % 10 == 0 || record_number == @import.total_count
          @import.update_columns(processed_count: record_number)

          # Emit structured progress event (Rails 8.1 Feature B)
          Rails.event.notify(
            "import.progress",
            import_id:       @import.id,
            processed:       record_number,
            total:           @import.total_count,
            percentage:      @import.progress_percentage
          )
        end

        # advance! saves cursor=record_number and calls stopping? on the adapter
        # If the queue adapter signals stop (e.g. Kamal deploy in progress),
        # the job pauses here and is re-enqueued to resume from record_number
        step.advance!(from: record_number)
      end
    end

    # -------------------------------------------------------------------------
    # STEP 3: finalize — method reference format (Rails 8.1 also supports this)
    # The method name must match a private method on the job class
    # -------------------------------------------------------------------------
    step :finalize
  end

  private

  # ---------------------------------------------------------------------------
  # Called by step :finalize (method reference format)
  # This is an alternative to the block format — both are valid in Rails 8.1
  # ---------------------------------------------------------------------------
  def finalize
    Rails.logger.info "[Continuable] Step: finalize — completing import ##{@import.id}"

    @import.update!(status: "completed", processed_count: @import.total_count)

    # Emit final structured event (Rails 8.1 Feature B)
    Rails.event.notify(
      "import.completed",
      import_id:   @import.id,
      name:        @import.name,
      total:       @import.total_count,
      completed_at: Time.current.iso8601
    )

    # Broadcast Turbo Stream update to the import show page
    broadcast_import_complete

    Rails.logger.info "[Continuable] ✅ Import ##{@import.id} (#{@import.name}) completed!"
  end

  # ---------------------------------------------------------------------------
  # Simulate processing a single record (CSV row, DB record, API call, etc.)
  # In production replace with real logic: parse, validate, upsert, etc.
  # ---------------------------------------------------------------------------
  def simulate_record_processing(record_number)
    # Simulate variable processing time (fast for demo purposes)
    sleep(0.01) if Rails.env.development?
    Rails.logger.debug "[Continuable]   Processing record ##{record_number}"
  end

  # ---------------------------------------------------------------------------
  # Broadcast Turbo Stream update so the /imports/:id page refreshes live
  # ---------------------------------------------------------------------------
  def broadcast_import_complete
    ActionCable.server.broadcast(
      "import_#{@import.id}",
      { status: "completed", processed: @import.total_count, total: @import.total_count }
    )
  rescue => e
    Rails.logger.warn "[Continuable] Broadcast failed: #{e.message}"
  end
end
