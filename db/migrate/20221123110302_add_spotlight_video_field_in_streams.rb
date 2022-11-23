class AddSpotlightVideoFieldInStreams < ActiveRecord::Migration[5.0]
  def change
    add_column :streams, :spotlight_video, :boolean, default: :false
  end
end
