# frozen_string_literal: true

class CreateBiomes < ActiveRecord::Migration[8.1]
  def change
    create_table :biomes do |t|
      t.string :name, null: false
      t.text :description, null: false

      t.timestamps
    end

    add_index :biomes, "lower((name)::text)", name: "index_biomes_on_lower_name", unique: true
  end
end
