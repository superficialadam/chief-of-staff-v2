class CoreSchema < ActiveRecord::Migration[8.0]
def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :projects, id: :uuid do |t|
      t.string  :name, null: false
      t.text    :description
      t.string  :status, null: false, default: "planned"   # planned|active|completed|archived
      t.date    :start_date
      t.date    :end_date
      t.jsonb   :links, default: {}
      t.timestamps
    end
    add_index :projects, :status

    create_table :tasks, id: :uuid do |t|
      t.uuid    :project_id, index: true                   # optional
      t.string  :title, null: false
      t.text    :description
      t.string  :status, null: false, default: "todo"      # todo|in_progress|done|blocked
      t.integer :estimated_effort
      t.integer :emotional_effort
      t.integer :actual_effort
      t.date    :due_date
      t.integer :priority
      t.timestamps
    end
    add_foreign_key :tasks, :projects, column: :project_id

    create_table :backlog_items, id: :uuid do |t|
      t.string  :title, null: false
      t.text    :description
      t.string  :source
      t.string  :status, null: false, default: "unsorted"   # unsorted|promoted|discarded
      t.uuid    :promoted_to_task_id, index: true
      t.timestamps
    end
    add_foreign_key :backlog_items, :tasks, column: :promoted_to_task_id

    create_table :ideas, id: :uuid do |t|
      t.string  :title, null: false
      t.text    :description
      t.string  :status, null: false, default: "raw"        # raw|incubating|active|archived
      t.uuid    :project_id, index: true                    # optional
      t.timestamps
    end
    add_foreign_key :ideas, :projects, column: :project_id

    create_table :people, id: :uuid do |t|
      t.string :name, null: false
      t.string :role
      t.string :email
      t.text   :notes
      t.timestamps
    end
    add_index :people, :email

    create_table :places, id: :uuid do |t|
      t.string :name, null: false
      t.string :location
      t.text   :notes
      t.timestamps
    end

    create_table :journal_entries, id: :uuid do |t|
      t.date    :entry_date, null: false
      t.string  :author, null: false, default: "user"       # user|agent
      t.text    :content, null: false
      t.string  :tags, array: true, default: []
      t.timestamps
    end
    add_index :journal_entries, :entry_date
    add_index :journal_entries, :tags, using: :gin

    # Global tags + polymorphic taggings
    create_table :tags, id: :uuid do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :tags, :name, unique: true

    create_table :taggings, id: :uuid do |t|
      t.uuid    :tag_id, null: false
      t.string  :taggable_type, null: false   # "Project"|"Task"|"Idea"|"Place"|"Person"
      t.uuid    :taggable_id, null: false
      t.timestamps
    end
    add_index :taggings, [ :taggable_type, :taggable_id ]
    add_index :taggings, [ :tag_id, :taggable_type, :taggable_id ], unique: true, name: "idx_unique_taggings"
    add_foreign_key :taggings, :tags

    # Many People attach to: projects, tasks, ideas, places
    create_table :entity_people, id: :uuid do |t|
      t.uuid   :person_id, null: false
      t.string :entity_type, null: false      # "Project"|"Task"|"Idea"|"Place"
      t.uuid   :entity_id, null: false
      t.string :role
      t.timestamps
    end
    add_index :entity_people, [ :entity_type, :entity_id ]
    add_index :entity_people, [ :person_id, :entity_type, :entity_id ], unique: true, name: "idx_unique_entity_people"
    add_foreign_key :entity_people, :people, column: :person_id

    # Many Places attach to: tasks, ideas, people
    create_table :entity_places, id: :uuid do |t|
      t.uuid   :place_id, null: false
      t.string :entity_type, null: false      # "Task"|"Idea"|"Person"
      t.uuid   :entity_id, null: false
      t.string :kind
      t.timestamps
    end
    add_index :entity_places, [ :entity_type, :entity_id ]
    add_index :entity_places, [ :place_id, :entity_type, :entity_id ], unique: true, name: "idx_unique_entity_places"
    add_foreign_key :entity_places, :places, column: :place_id
  end
end
