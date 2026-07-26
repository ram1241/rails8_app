class CreateImports < ActiveRecord::Migration[8.1]
  def change
    create_table :imports do |t|
      t.string  :name,            null: false
      t.string  :status,          null: false, default: "pending"
      t.integer :processed_count, null: false, default: 0
      t.integer :total_count,     null: false, default: 0
      t.text    :error_message

      t.timestamps
    end
  end
end
