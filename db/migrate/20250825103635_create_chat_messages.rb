class CreateChatMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_messages do |t|
      t.string :role
      t.text :content
      t.datetime :timestamp

      t.timestamps
    end
  end
end
