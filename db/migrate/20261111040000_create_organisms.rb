# frozen_string_literal: true

class CreateOrganisms < ActiveRecord::Migration[8.1]
  def change
    create_table :organisms do |t|
      t.references :species, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description, null: false
      t.jsonb :themes, default: [], null: false

      t.timestamps
    end

    add_index :organisms, "species_id, lower((name)::text)", name: "index_organisms_on_species_id_and_lower_name", unique: true
  end
end
