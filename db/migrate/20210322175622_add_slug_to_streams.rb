class AddSlugToStreams < ActiveRecord::Migration[5.0]
  def change
    add_column :streams, :slug, :string
    add_column :streams, :video_type, :string, default: 'live'
    add_column :streams, :duration, :integer, default: 0
  end
end
