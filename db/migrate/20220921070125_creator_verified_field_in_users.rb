class CreatorVerifiedFieldInUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :creator_verified, :boolean
  end
end
