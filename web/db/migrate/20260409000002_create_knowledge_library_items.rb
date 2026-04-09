class CreateKnowledgeLibraryItems < ActiveRecord::Migration[8.0]
  def change
    create_table :knowledge_library_items, id: :uuid do |t|
      t.references :node, type: :uuid, foreign_key: { to_table: :ledger_nodes }, null: true
      t.string :source_path, null: true
      t.string :source_sha, null: true
      t.integer :chunk_index, null: false
      t.string :content_type, null: false
      t.text :content, null: false
      t.column :embedding, :vector, limit: 1536, null: false
      t.uuid :org_id, null: false

      t.timestamps
    end

    add_index :knowledge_library_items, %i[source_path chunk_index], unique: true, name: 'idx_library_items_source_path_chunk'
    add_index :knowledge_library_items, :org_id
  end
end
