class AddMuxAudioUrlInTrack < ActiveRecord::Migration[5.0]
  def change
    add_column :tracks, :mux_audio_url_1, :text
    add_column :tracks, :mux_audio_id_1, :string
    add_column :tracks, :mux_audio_url_2, :text
    add_column :tracks, :mux_audio_id_2, :string
  end
end
