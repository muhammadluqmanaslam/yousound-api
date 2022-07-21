class CreateSmsMessages < ActiveRecord::Migration[5.0]
  def change
    create_table :sms_messages do |t|
      t.references :user
      t.references :sent_to, references: :user
      t.text :message
      t.string :message_sid

      t.timestamps
    end 
  end
end
