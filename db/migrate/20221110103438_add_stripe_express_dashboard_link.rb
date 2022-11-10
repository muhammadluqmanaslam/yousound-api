class AddStripeExpressDashboardLink < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :stripe_express_dashboard_link, :string
  end
end
