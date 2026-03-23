# frozen_string_literal: true

class Message < ApplicationRecord
  ROLES = %w[ai candidate].freeze

  belongs_to :conversation

  validates :role,     inclusion: { in: ROLES }
  validates :content,  presence: true
  validates :position, presence: true, uniqueness: { scope: :conversation_id }

  before_validation :set_position, on: :create

  # Returns the metadata column parsed as a symbolized hash.
  #
  # @return [Hash] parsed metadata, or {} on blank/invalid JSON
  def metadata_hash
    return {} if metadata.blank?
    JSON.parse(metadata, symbolize_names: true)
  rescue JSON::ParserError
    {}
  end

  private

  def set_position
    self.position ||= (conversation&.messages&.maximum(:position) || 0) + 1
  end
end
