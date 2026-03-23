# frozen_string_literal: true

class Job < ApplicationRecord
  has_one :scenario, dependent: :destroy
  has_many :candidates, dependent: :destroy

  scope :active, -> { where(status: "active") }
  scope :closed, -> { where(status: "closed") }

  validates :title, presence: true
  validates :status, inclusion: { in: %w[active closed] }
  inquirer :status
end
