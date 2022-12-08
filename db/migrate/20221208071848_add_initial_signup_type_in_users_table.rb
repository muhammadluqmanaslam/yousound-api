class AddInitialSignupTypeInUsersTable < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :initial_signup_type, :string
  end
end
