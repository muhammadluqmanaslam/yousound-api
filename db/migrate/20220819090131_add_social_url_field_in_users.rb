class AddSocialUrlFieldInUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :social_url, :string, default: ''
  end
end
