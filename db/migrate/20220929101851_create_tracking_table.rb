class CreateTrackingTable < ActiveRecord::Migration[5.0]
  def change
    create_table :trackings do |t|
      t.integer :creator_id
      t.integer :listener_id
      t.integer :duration

      t.references :track
      t.references :stream
      t.boolean :active, default: :true
      t.timestamps
    end
  end
end
