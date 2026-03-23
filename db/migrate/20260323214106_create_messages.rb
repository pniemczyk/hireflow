# frozen_string_literal: true

class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.integer  :conversation_id, null: false
      t.string   :role,            null: false
      t.text     :content,         null: false
      t.text     :metadata,        default: '{}'
      t.integer  :position,        null: false

      t.timestamps
    end

    add_index :messages, :conversation_id
    add_index :messages, %i[conversation_id position], unique: true
    add_foreign_key :messages, :conversations
  end
end
