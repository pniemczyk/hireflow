# frozen_string_literal: true

class AddInterviewSummaryToCandidates < ActiveRecord::Migration[8.1]
  def change
    add_column :candidates, :interview_summary, :text
  end
end
