class AddCreatorRerequestedAt < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :re_requested_at, :datetime
  end
end
