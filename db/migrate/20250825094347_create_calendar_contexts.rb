class CreateCalendarContexts < ActiveRecord::Migration[8.0]
  def change
    create_table :calendar_contexts do |t|
      t.json :events
      t.datetime :fetched_at

      t.timestamps
    end
  end
end
