# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Hubspot::File do
  before do
    Hubspot.configure do |config|
      config.access_token = 'test_token'
    end
  end

  describe '.create' do
    let(:file_path) { 'spec/fixtures/test.png' }
    let(:url) { 'https://api.hubapi.com/files/v3/files' }

    before do
      # Create a dummy file for testing
      File.write(file_path, 'fake image content')
    end

    after do
      File.delete(file_path) if File.exist?(file_path)
    end

    it 'uploads a file' do
      stub_request(:post, url)
        .with do |request|
          request.headers['Authorization'] == 'Bearer test_token' &&
            request.headers['Content-Type'] != 'application/json' &&
            request.body.include?('fake image content')
        end
        .to_return(
          status: 201,
          body: { id: '123', name: 'test.png' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      file_obj = Hubspot::File.create(file_path)
      expect(file_obj).to be_a(Hubspot::File)
      expect(file_obj.id).to eq('123')
    end

    it 'sets default access to PRIVATE' do
      stub_request(:post, url)
        .with do |request|
          request.body.include?('"access":"PRIVATE"')
        end
        .to_return(
          status: 201,
          body: { id: '123', name: 'test.png' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      Hubspot::File.create(file_path)
    end

    it 'passes options correctly' do
      stub_request(:post, url)
        .with do |request|
          request.body.include?('folder_id_123') &&
            request.body.include?('PUBLIC_INDEXABLE')
        end
        .to_return(
          status: 201,
          body: { id: '124', name: 'test.png' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      file_obj = Hubspot::File.create(file_path, folderId: 'folder_id_123', options: { access: 'PUBLIC_INDEXABLE' })
      expect(file_obj).to be_a(Hubspot::File)
    end

    it 'uploads a file blob (IO object)' do
      stub_request(:post, url)
        .with do |request|
          request.body.include?('fake image content')
        end
        .to_return(
          status: 201,
          body: { id: '125', name: 'blob.png' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      file_blob = File.open(file_path)
      file_obj = Hubspot::File.create(file_blob)
      expect(file_obj).to be_a(Hubspot::File)
      expect(file_obj.id).to eq('125')
      file_blob.close
    end

    it 'uploads from memory (StringIO)' do
      stub_request(:post, url)
        .with do |request|
          request.body.include?('memory content')
        end
        .to_return(
          status: 201,
          body: { id: '126', name: 'memory.txt' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      require 'stringio'
      blob = StringIO.new('memory content')

      file_obj = Hubspot::File.create(blob, fileName: 'memory.txt')
      expect(file_obj).to be_a(Hubspot::File)
      expect(file_obj.id).to eq('126')
    end
  end

  describe '.find' do
    let(:file_id) { '123' }
    let(:url) { "https://api.hubapi.com/files/v3/files/#{file_id}" }

    it 'retrieves a file' do
      stub_request(:get, url)
        .with(headers: { 'Authorization' => 'Bearer test_token' })
        .to_return(
          status: 200,
          body: { id: file_id, name: 'test.png' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      file = Hubspot::File.find(file_id)
      expect(file).to be_a(Hubspot::File)
      expect(file.id).to eq(file_id)
      expect(file['name']).to eq('test.png')
    end
  end

  describe '.find_by_path' do
    let(:file_path) { 'images/logo.png' }
    let(:url) { "https://api.hubapi.com/files/v3/files/stat/#{file_path}" }

    it 'retrieves a file by path' do
      stub_request(:get, url)
        .with(headers: { 'Authorization' => 'Bearer test_token' })
        .to_return(
          status: 200,
          body: { id: '123', name: 'logo.png', path: file_path }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      file = Hubspot::File.find_by_path(file_path)
      expect(file).to be_a(Hubspot::File)
      expect(file.id).to eq('123')
      expect(file['path']).to eq(file_path)
    end

    it 'returns nil if file does not exist' do
      stub_request(:get, url)
        .with(headers: { 'Authorization' => 'Bearer test_token' })
        .to_return(
          status: 404,
          body: { status: 'error', message: 'No file or folder exists at path' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      file = Hubspot::File.find_by_path(file_path)
      expect(file).to be_nil
    end
  end

  describe '.update' do
    let(:file_id) { '123' }
    let(:url) { "https://api.hubapi.com/files/v3/files/#{file_id}" }
    let(:file_path) { 'spec/fixtures/test.png' }

    before do
      File.write(file_path, 'fake replacement content')
    end
    after do
      File.delete(file_path) if File.exist?(file_path)
    end

    it 'updates a file content (PUT)' do
      stub_request(:put, url)
        .with do |request|
          request.body.include?('fake replacement content') &&
          request.body.include?('"access":"PRIVATE"')
        end
        .to_return(
          status: 200,
          body: { id: file_id, name: 'test.png' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      file = Hubspot::File.update(file_id, file_path)
      expect(file).to be_a(Hubspot::File)
      expect(file.id).to eq(file_id)
    end

    it 'updates a file content with StringIO' do
      stub_request(:put, url)
        .with do |request|
          request.body.include?('memory content')
        end
        .to_return(
          status: 200,
          body: { id: file_id, name: 'test.png' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      require 'stringio'
      blob = StringIO.new('memory content')
      file = Hubspot::File.update(file_id, blob, fileName: 'replacement.txt')
      expect(file).to be_a(Hubspot::File)
      expect(file.id).to eq(file_id)
    end
  end

  describe '#update' do
    let(:file_id) { '123' }
    let(:url) { "https://api.hubapi.com/files/v3/files/#{file_id}" }
    let(:file_path) { 'spec/fixtures/test.png' }

    before do
      File.write(file_path, 'fake replacement content')
    end
    after do
      File.delete(file_path) if File.exist?(file_path)
    end

    it 'updates file content via instance method' do
      stub_request(:put, url)
        .with do |request|
          request.body.include?('fake replacement content')
        end
        .to_return(
          status: 200,
          body: { id: file_id, name: 'test.png', updated: true }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      file = Hubspot::File.new('id' => file_id)
      updated_file = file.update(file_path)
      expect(updated_file).to be_a(Hubspot::File)
      expect(updated_file['updated']).to be true
      expect(file['updated']).to be true
    end

    it 'updates file content via instance method initialized with symbols' do
      stub_request(:put, url)
        .with do |request|
          request.body.include?('memory content')
        end
        .to_return(
          status: 200,
          body: { id: file_id, name: 'test.png', updated: true }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      require 'stringio'
      blob = StringIO.new('memory content')

      file = Hubspot::File.new(id: file_id)
      updated_file = file.update(blob, fileName: 'replacement.txt')
      expect(updated_file).to be_a(Hubspot::File)
    end
  end

  describe '.delete' do
    let(:file_id) { '123' }
    let(:url) { "https://api.hubapi.com/files/v3/files/#{file_id}" }

    it 'deletes a file' do
      stub_request(:delete, url)
        .with(headers: { 'Authorization' => 'Bearer test_token' })
        .to_return(status: 204)

      result = Hubspot::File.delete(file_id)
      expect(result).to be true
    end
  end

  describe '#delete' do
    let(:file_id) { '123' }
    let(:url) { "https://api.hubapi.com/files/v3/files/#{file_id}" }

    it 'deletes the file instance' do
      stub_request(:delete, url)
        .with(headers: { 'Authorization' => 'Bearer test_token' })
        .to_return(status: 204)

      file = Hubspot::File.new('id' => file_id)
      result = file.delete
      expect(result).to be true
    end
  end

  describe '#initialize' do
    it 'initializes correctly when attributes are nested under file key' do
      attributes = { 'file' => { 'id' => '999', 'name' => 'nested.png' }, 'folder' => {} }
      file = Hubspot::File.new(attributes)
      expect(file.id).to eq('999')
    end
  end
end
