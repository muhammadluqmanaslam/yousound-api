class AlterResponseFieldInShopOrders < ActiveRecord::Migration[5.0]
  def change
    rename_column :shop_orders, :stripe_respoinse, :stripe_response
  end
end
