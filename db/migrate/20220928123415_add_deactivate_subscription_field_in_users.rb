class AddDeactivateSubscriptionFieldInUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :deactivate_subscription, :boolean, default: :false
  end
end
