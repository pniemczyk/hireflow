class CreateCandidates < ActiveRecord::Migration[8.1]
  def change
    create_table :candidates do |t|
      t.references :job, null: false, foreign_key: true
      t.string :name
      t.string :email
      t.string :status, null: false, default: 'new'
      t.text :cv_raw_text

      t.timestamps
    end
  end
end
