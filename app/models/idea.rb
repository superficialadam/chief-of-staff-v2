# app/models/idea.rb
class Idea < ApplicationRecord
  belongs_to :project, optional: true

  has_many :entity_people, as: :entity, dependent: :destroy
  has_many :people, through: :entity_people

  has_many :entity_places, as: :entity, dependent: :destroy
  has_many :places, through: :entity_places

  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  validates :title, presence: true
end
