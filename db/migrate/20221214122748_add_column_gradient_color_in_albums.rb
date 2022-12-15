class AddColumnGradientColorInAlbums < ActiveRecord::Migration[5.0]
  def change
    add_column :albums, :gradient_color, :string
    add_column :shop_products, :gradient_color, :string
  end
end
