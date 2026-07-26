class ProjectsController < ApplicationController
  before_action :set_project, only: %i[ show edit update destroy ]

  # ===========================================================================
  # SOLID CACHE — Low-level cache demo in index
  # ===========================================================================
  # Rails.cache uses SolidCache in production (config/cache.yml → cache.sqlite3)
  # In development: uses :memory_store (config/environments/development.rb)
  #
  # To test Solid Cache in development:
  #   bin/rails dev:cache   ← toggles caching on/off in development
  #
  # Cache key strategy:
  #   "projects/count"     → stores total project count
  #   "projects/stats"     → stores aggregate stats hash
  #   Both expire after 5 minutes automatically
  # ===========================================================================

  # GET /projects or /projects.json
  def index
    @projects = Project.all

    # Low-level caching: fetch returns cached value or executes the block once
    # Subsequent requests within 5 minutes skip the DB query entirely
    @projects_count = Rails.cache.fetch("projects/count", expires_in: 5.minutes) do
      Project.count
    end

    @active_count = Rails.cache.fetch("projects/active_count", expires_in: 5.minutes) do
      Project.where(archived: false).count
    end

    @archived_count = Rails.cache.fetch("projects/archived_count", expires_in: 5.minutes) do
      Project.where(archived: true).count
    end
  end

  # GET /projects/1 or /projects/1.json or /projects/1.md
  # ===========================================================================
  # RAILS 8.1 — MARKDOWN RENDERING
  # ===========================================================================
  # format.md { render markdown: @project } uses the new built-in Markdown
  # renderer added in Rails 8.1. The object passed to `render markdown:` must
  # respond to #to_markdown — which we define on the Project model.
  #
  # Access the markdown version at: GET /projects/1.md
  # Or via Accept: text/markdown header
  #
  # Rails 8.1 automatically:
  #   1. Converts @project.to_markdown to HTML using a built-in renderer
  #   2. Wraps it in the application layout
  #   3. Sets Content-Type: text/markdown for raw .md requests
  # ===========================================================================
  def show
    respond_to do |format|
      format.html
      format.json
      format.md { render markdown: @project }
    end
  end

  # GET /projects/new
  def new
    @project = Project.new
  end

  # GET /projects/1/edit
  def edit
  end

  # POST /projects or /projects.json
  def create
    @project = Project.new(project_params)

    respond_to do |format|
      if @project.save
        # Expire cache entries so the counts are fresh after a new project
        expire_project_caches
        format.html { redirect_to @project, notice: "Project was successfully created." }
        format.json { render :show, status: :created, location: @project }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @project.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /projects/1 or /projects/1.json
  def update
    respond_to do |format|
      if @project.update(project_params)
        expire_project_caches
        format.html { redirect_to @project, notice: "Project was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @project }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @project.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /projects/1 or /projects/1.json
  def destroy
    @project.destroy!
    expire_project_caches

    respond_to do |format|
      format.html { redirect_to projects_path, notice: "Project was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def set_project
    @project = Project.find(params.expect(:id))
  end

  def project_params
    params.expect(project: [ :title, :description, :notes ])
  end

  # ===========================================================================
  # SOLID CACHE — Expire related cache entries after data changes
  # Pattern: delete specific keys when underlying data changes
  # ===========================================================================
  def expire_project_caches
    Rails.cache.delete("projects/count")
    Rails.cache.delete("projects/active_count")
    Rails.cache.delete("projects/archived_count")
  end
end
