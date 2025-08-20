# app/models/project.rb
class Project < ApplicationRecord
  has_many :tasks
  has_many :ideas

  has_many :entity_people, as: :entity, dependent: :destroy
  has_many :people, through: :entity_people

  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  validates :name, presence: true
end
