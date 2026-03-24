require 'rails_helper'

RSpec.describe 'Active Storage configuration' do
  describe 'test environment' do
    it 'uses the test disk adapter' do
      expect(Rails.configuration.active_storage.service).to eq(:test)
    end

    it 'configures a test disk service in storage.yml' do
      configs = Rails.application.config.active_storage.service_configurations
      expect(configs['test']['service']).to eq('Disk')
    end
  end

  describe 'storage.yml' do
    let(:configs) { Rails.application.config.active_storage.service_configurations }

    it 'defines a minio service with S3 adapter' do
      expect(configs['minio']['service']).to eq('S3')
    end

    it 'configures minio with path-style access' do
      expect(configs['minio']['force_path_style']).to be true
    end

    it 'sets the minio bucket to sovereign-library' do
      expect(configs['minio']['bucket']).to eq('sovereign-library')
    end
  end
end
