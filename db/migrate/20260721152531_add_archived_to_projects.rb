class AddArchivedToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :archived, :boolean
  end
end
