class AddEvaluationResultToCandidates < ActiveRecord::Migration[8.1]
  def change
    add_column :candidates, :evaluation_result, :text
  end
end
