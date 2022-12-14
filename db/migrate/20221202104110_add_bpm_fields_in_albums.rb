class AddBpmFieldsInAlbums < ActiveRecord::Migration[5.0]
  def change
    add_column :albums, :bpm, :integer
    add_column :albums, :bpm_key, :string
    add_column :albums, :bpm_value, :string
  end
end
