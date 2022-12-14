class CreatePlaylists < ActiveRecord::Migration[5.0]
  def change
    create_table :playlists do |t|
      t.string :name
      t.boolean :playlist_public
      t.references :user

      t.timestamps
    end
  end
end
