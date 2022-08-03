class AddMaskedPhoneNumberField < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :masked_phone_number, :string
  end
end
