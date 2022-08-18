class AddFieldsInUsersForSignup < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :age_group, :string, default: ''
  end
end
