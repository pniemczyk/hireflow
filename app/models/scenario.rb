# frozen_string_literal: true

class Scenario < ApplicationRecord
  belongs_to :job

  validates :content, presence: true
end
