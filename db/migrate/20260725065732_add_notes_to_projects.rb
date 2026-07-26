class AddNotesToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :notes, :text
  end
end
