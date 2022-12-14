class AddDurationFieldInTracks < ActiveRecord::Migration[5.0]
  def change
    add_column :tracks, :duration, :float
  end
end
