# app/models/place.rb
class Place < ApplicationRecord
  # People attached to this place (entity_people with entity_type "Place")
  has_many :entity_people, as: :entity, dependent: :destroy
  has_many :people, through: :entity_people

  # Entities that reference this place (Task/Idea/Person via entity_places)
  has_many :entity_places, dependent: :destroy

  has_many :tasks, through: :entity_places, source: :entity, source_type: "Task"
  has_many :ideas, through: :entity_places, source: :entity, source_type: "Idea"

  # Tagging on places is allowed
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  validates :name, presence: true
end
