# frozen_string_literal: true

class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.integer  :candidate_id, null: false
      t.string   :state,        null: false, default: 'in_progress'
      t.datetime :started_at,   null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.datetime :completed_at

      t.timestamps
    end

    add_index :conversations, :candidate_id, unique: true
    add_foreign_key :conversations, :candidates
  end
end
