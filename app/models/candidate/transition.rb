# frozen_string_literal: true

class Candidate::Transition < ApplicationRecord
  include Statesman::Adapters::ActiveRecordTransition

  self.table_name = "candidate_transitions"

  belongs_to :candidate, class_name: "Candidate"

  attribute :most_recent, :boolean, default: false
  attribute :to_state, :string
  attribute :sort_key, :integer

  validates :to_state, inclusion: { in: Candidate::StateMachine.states }
end
