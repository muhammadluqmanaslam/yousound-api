class CreateTableCollectionDetails < ActiveRecord::Migration[5.0]
  def change
    create_table :collections do |t|
      t.references :user
      t.references :album
      t.references :track
      t.references :stream
      t.references :shop_product

      t.timestamps
    end
  end
end
