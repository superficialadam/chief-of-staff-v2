# app/models/person.rb
class Person < ApplicationRecord
  has_many :entity_people, dependent: :destroy

  # Tags on people (allowed per your spec)
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  # Places linked to this person
  has_many :entity_places, as: :entity, dependent: :destroy
  has_many :places, through: :entity_places

  validates :name, presence: true
end
