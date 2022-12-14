class AddPlaylistTypeInPlaylists < ActiveRecord::Migration[5.0]
  def change
    add_column :playlists, :playlist_type, :string
  end
end
