class CreateScenarios < ActiveRecord::Migration[8.1]
  def change
    create_table :scenarios do |t|
      t.references :job, null: false, foreign_key: true
      t.text :content, null: false
      t.integer :version, null: false, default: 1

      t.timestamps
    end
  end
end
