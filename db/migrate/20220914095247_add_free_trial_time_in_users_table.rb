class AddFreeTrialTimeInUsersTable < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :free_trial_time, :integer, default: 5400
  end
end
