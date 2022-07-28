class AddTypeFieldInStripeResponse < ActiveRecord::Migration[5.0]
  def change
    add_column :stripe_response, :response_type, :string
  end
end
