class ImportsController < ApplicationController
  # ===========================================================================
  # RAILS 8.1 — ACTIVE JOB CONTINUATIONS DEMO
  # ===========================================================================
  # This controller manages Import records and kicks off ProcessImportJob,
  # which demonstrates ActiveJob::Continuable — Rails 8.1's resumable jobs.
  #
  # Flow:
  #   GET  /imports/new   → form to create an import (name + total_count)
  #   POST /imports        → create Import record + enqueue ProcessImportJob
  #   GET  /imports/:id   → live progress page (polls via Turbo)
  # ===========================================================================

  def index
    @imports = Import.recent
  end

  def new
    @import = Import.new
  end

  def create
    @import = Import.new(import_params)

    if @import.save
      # Enqueue the Continuable job — it will process records step-by-step
      # and can survive interruptions (deploys, restarts) by resuming from cursor
      ProcessImportJob.perform_later(@import.id)

      # Emit a structured event (Rails 8.1 Feature B) for import kick-off
      Rails.event.notify(
        "import.enqueued",
        import_id: @import.id,
        name:      @import.name,
        total:     @import.total_count
      )

      redirect_to import_path(@import),
        notice: "Import '#{@import.name}' started! #{@import.total_count} records queued."
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @import = Import.find(params[:id])

    respond_to do |format|
      format.html
      format.json do
        render json: {
          id:               @import.id,
          status:           @import.status,
          processed_count:  @import.processed_count,
          total_count:      @import.total_count,
          progress:         @import.progress_percentage
        }
      end
    end
  end

  private

  def import_params
    params.expect(import: [ :name, :total_count ])
  end
end
