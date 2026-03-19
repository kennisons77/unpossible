class CreateConcerns < ActiveRecord::Migration[8.0]
  def change
    create_table :concerns do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.boolean :llm_proposed, null: false, default: true
      t.datetime :confirmed_at

      t.timestamps
    end

    add_index :concerns, %i[owner_id name], unique: true
  end
end
