class CreateStripeResponseTable < ActiveRecord::Migration[5.0]
  def change
    create_table :stripe_response do |t|
      t.references :user
      t.text :response

      t.timestamps
    end
  end
end
