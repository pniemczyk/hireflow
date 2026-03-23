# frozen_string_literal: true

class CreateCandidateTransitions < ActiveRecord::Migration[8.1]
  def change
    # Instead of t.references with foreign_key: true, you can use:
    # t.string :candidate_id, null: false
    # And separately add foreign key:
    # add_foreign_key :candidate_transitions, :candidates , column: :candidate_id, primary_key: :id

    create_table :candidate_transitions do |t|
      t.references :candidate, null: false, foreign_key: true # Use type when referencing model uses non-default primary key type. Example: type: :string
      t.string :to_state, null: false
      t.json :metadata, default: {}
      t.boolean :most_recent, default: false
      t.integer :sort_key, null: false
      t.timestamps null: false
    end

    add_index(:candidate_transitions,
              %i[candidate_id sort_key],
              unique: true,
              name: "index_candidate_transition_parent_sort")
    add_index(:candidate_transitions,
              %i[candidate_id most_recent],
              unique: true,
              where: "most_recent",
              name: "index_candidate_transition_parent_most_recent")
  end
end
