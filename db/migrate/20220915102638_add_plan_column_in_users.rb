class AddPlanColumnInUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :plan, :string
  end
end
