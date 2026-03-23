class CreateJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :jobs do |t|
      t.string :title, null: false
      t.text :description
      t.string :status, null: false, default: 'active'

      t.timestamps
    end
  end
end
