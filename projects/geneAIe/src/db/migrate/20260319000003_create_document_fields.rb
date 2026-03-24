class CreateDocumentFields < ActiveRecord::Migration[8.0]
  def change
    create_table :document_fields do |t|
      t.references :document, null: false, foreign_key: true
      t.string :field_name, null: false
      t.text :value
      t.integer :source, null: false

      t.timestamps
    end

    add_index :document_fields, %i[document_id field_name]
  end
end
