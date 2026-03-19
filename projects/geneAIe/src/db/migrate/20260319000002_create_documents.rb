class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'vector' unless extension_enabled?('vector')

    create_table :documents do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.references :concern, foreign_key: true
      t.integer :stage, null: false, default: 0
      t.boolean :review_required, null: false, default: false
      t.string :review_reason
      t.string :content_hash
      t.float :confidence_score
      t.string :minio_blob_key
      t.string :markdown_path
      t.string :document_type
      t.string :concern_tags, array: true, default: []
      t.column :embedding, :vector, limit: 1536

      t.timestamps
    end

    add_index :documents, :stage
    add_index :documents, :content_hash
    add_index :documents, :review_required
  end
end
