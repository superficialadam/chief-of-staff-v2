class AddTimeRangeToCalendarContext < ActiveRecord::Migration[8.0]
  def change
    add_column :calendar_contexts, :time_min, :datetime
    add_column :calendar_contexts, :time_max, :datetime
  end
end
