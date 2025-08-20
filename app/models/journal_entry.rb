# app/models/journal_entry.rb
class JournalEntry < ApplicationRecord
  validates :entry_date, :author, :content, presence: true
end
