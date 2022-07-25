class AddFieldInShopOrder < ActiveRecord::Migration[5.0]
  def change
    add_column :shop_orders, :stripe_respoinse, :text
  end
end
