class AddShortDescriptionToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :short_description, :text
  end
end
