class CreatePlaylistDetails < ActiveRecord::Migration[5.0]
  def change
    create_table :playlist_details do |t|
      t.references :playlist
      t.references :track
      t.references :stream
      t.references :shop_product

      t.timestamps
    end
  end
end
