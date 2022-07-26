class AddChargeFieldInShopOrders < ActiveRecord::Migration[5.0]
  def change
    add_column :shop_orders, :stripe_charge_id, :string
  end
end
