# frozen_string_literal: true

# Ensure the MinIO bucket exists on boot (development/production only).
# Test environment uses the :test disk adapter and skips this entirely.
Rails.application.config.after_initialize do
  next unless Rails.configuration.active_storage.service.in?(%i[minio])

  require "aws-sdk-s3"

  storage_yaml = YAML.safe_load(
    ERB.new(Rails.root.join("config/storage.yml").read).result,
    permitted_classes: [], aliases: true
  )
  bucket_name = storage_yaml.dig("minio", "bucket")
  next unless bucket_name

  client = Aws::S3::Client.new(
    access_key_id: ENV.fetch("AWS_ACCESS_KEY_ID"),
    secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY"),
    region: "us-east-1",
    endpoint: ENV.fetch("AWS_ENDPOINT"),
    force_path_style: true
  )

  client.head_bucket(bucket: bucket_name)
rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchBucket
  client.create_bucket(bucket: bucket_name)
  Rails.logger.info("Created MinIO bucket: #{bucket_name}")
rescue Aws::Errors::ServiceError => e
  Rails.logger.warn("Could not verify MinIO bucket '#{bucket_name}': #{e.message}")
end
