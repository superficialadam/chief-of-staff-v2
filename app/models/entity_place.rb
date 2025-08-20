# app/models/entity_place.rb
class EntityPlace < ApplicationRecord
  self.table_name = "entity_places"

  belongs_to :place
  belongs_to :entity, polymorphic: true  # Task | Idea | Person

  # Optional: validates :kind, inclusion: { in: %w[meeting storage home office other] }, allow_nil: true
end
