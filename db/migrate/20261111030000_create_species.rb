# frozen_string_literal: true

class CreateSpecies < ActiveRecord::Migration[8.1]
  def change
    create_table :species do |t|
      t.references :biome, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description, null: false
      t.jsonb :themes, default: [], null: false

      t.timestamps
    end

    add_index :species, "biome_id, lower((name)::text)", name: "index_species_on_biome_id_and_lower_name", unique: true
  end
end
