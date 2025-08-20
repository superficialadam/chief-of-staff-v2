# app/models/backlog_item.rb
class BacklogItem < ApplicationRecord
  belongs_to :promoted_task, class_name: "Task", foreign_key: :promoted_to_task_id, optional: true

  validates :title, presence: true
end
