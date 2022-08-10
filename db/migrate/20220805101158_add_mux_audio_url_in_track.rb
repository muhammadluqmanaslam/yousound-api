class AddMuxAudioUrlInTrack < ActiveRecord::Migration[5.0]
  def change
    add_column :tracks, :mux_audio_url_1, :text
    add_column :tracks, :mux_audio_id_1, :string
    add_column :tracks, :mux_audio_url_2, :text
    add_column :tracks, :mux_audio_id_2, :string
    add_column :tracks, :mp_channel_1_ep_1_id, :string
    add_column :tracks, :mp_channel_1_ep_1_url, :string
    add_column :tracks, :mp_channel_2_ep_1_id, :string
    add_column :tracks, :mp_channel_2_ep_1_url, :string
  end
end
