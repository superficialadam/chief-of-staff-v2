# app/models/entity_person.rb
class EntityPerson < ApplicationRecord
  self.table_name = "entity_people"

  belongs_to :person
  belongs_to :entity, polymorphic: true  # Project | Task | Idea | Place

  # Optional: validates :role, inclusion: { in: %w[owner collaborator stakeholder] }, allow_nil: true
end
