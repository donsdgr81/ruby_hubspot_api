# frozen_string_literal: true

require_relative './api_client'
require 'delegate'
require 'json'

module Hubspot
  # Handles file operations via the HubSpot Files API V3
  class File < ApiClient
    BASE_URL = '/files/v3/files'

    # Remove the Content-Type header inherited from ApiClient to allow multipart uploads
    default_options[:headers].delete('Content-Type')

    attr_reader :id, :attributes

    # Wrapper to allow uploading IO objects that don't respond to path/original_filename
    class IOAdapter < SimpleDelegator
      attr_reader :original_filename, :content_type

      def initialize(io, filename, content_type = 'application/octet-stream')
        super(io)
        @original_filename = filename
        @content_type = content_type
      end

      def path
        @original_filename
      end
    end

    def initialize(attributes)
      @attributes = attributes.transform_keys(&:to_s)
      @id = @attributes['id'] || @attributes.dig('file', 'id')
    end

    def delete
      self.class.delete(@id)
    end

    def update(file_path_or_io, options = {})
      self.class.update(@id, file_path_or_io, options).tap do |new_file|
        @attributes = new_file.attributes
      end
    end

    def [](key)
      @attributes[key.to_s]
    end

    class << self
      def create(file_path_or_io, options = {})
        payload = {}
        payload[:file] = prepare_file_payload(file_path_or_io, options)

        [:folderId, :folderPath, :fileName, :charset].each do |key|
          payload[key] = options[key] if options[key]
        end

        payload[:options] = prepare_api_options(options[:options]).to_json

        # Content-Type header is removed in default_options for this class
        response = post(BASE_URL, body: payload)
        new(handle_response(response))
      end

      def find(id)
        response = get("#{BASE_URL}/#{id}")
        new(handle_response(response))
      end

      def find_by_path(path)
        response = get("#{BASE_URL}/stat/#{path}")
        return nil if response.code == 404

        new(handle_response(response))
      end

      def update(id, file_path_or_io, options = {})
        payload = {}
        payload[:file] = prepare_file_payload(file_path_or_io, options)

        [:fileName, :charset].each do |key|
          payload[key] = options[key] if options[key]
        end

        payload[:options] = prepare_api_options(options[:options]).to_json

        response = put("#{BASE_URL}/#{id}", body: payload)
        new(handle_response(response))
      end

      def delete(id)
        response = super("#{BASE_URL}/#{id}")

        # DELETE usually returns 204 No Content
        return true if response.code == 204

        handle_response(response)
        true
      end

      private

      def prepare_file_payload(file_path_or_io, options)
        file_object = if file_path_or_io.is_a?(String)
                        ::File.open(file_path_or_io)
                      else
                        file_path_or_io
                      end

        # If it's an IO object but doesn't have path/original_filename, and we have fileName in options, wrap it.
        if options[:fileName] && !file_object.respond_to?(:path) && !file_object.respond_to?(:original_filename)
          file_object = IOAdapter.new(file_object, options[:fileName])
        end

        file_object
      end

      def prepare_api_options(user_options)
        opts = user_options || {}
        if opts.is_a?(String)
          opts = JSON.parse(opts)
        end

        opts = opts.transform_keys(&:to_s)
        opts['access'] ||= 'PRIVATE'
        opts
      end
    end
  end
end
