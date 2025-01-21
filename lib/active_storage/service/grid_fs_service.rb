# frozen_string_literal: true
require "active_storage"
require "active_storage/service"
module ActiveStorage
  # This service is for interacting with files in a MongoDB GridFS storage.
  class Service::GridFSService < Service

    # Initializes a new GridFSService.
    #
    # @param [ String ] database The name of the database to connect to.
    # @param [ String ] uri The URI of the MongoDB server.
    # @param [ String ] bucket The name of the GridFS bucket (default "fs").
    # @param **options Any additional options.
    def initialize(database:, uri:, bucket: "fs", **options)
      @client = Mongo::Client.new(uri, { database: database })
      @fs_bucket = Mongo::Grid::FSBucket.new(@client.database, bucket_name: bucket)
    end

    # Uploads a file to GridFS.
    #
    # @param [ String ] key The identifier for the file in storage.
    # @param [ IO ] io The IO object containing the file data.
    # @param [ String | Nil ] checksum The checksum of the file for verification
    # @param **options Additional metadata options.
    def upload(key, io, checksum: nil, **options)
      instrument :upload, key: key, checksum: checksum do
        blob = ActiveStorage::Blob.find_by(key: key)
        metadata = { original_filename: blob.filename.to_s }
        metadata.merge!(options[:metadata]) if options[:metadata].present?
        @fs_bucket.upload_from_stream(key, io, metadata: metadata)
      end
    end

    # Downloads a file from GridFS.
    #
    # @param [ String ] key The identifier for the file.
    # @return [ String ] The file data.
    def download(key)
      instrument :download, key: key do
        @fs_bucket.open_download_stream_by_name(key) do |stream|
          return stream.read
        end
      end
    end

    # Downloads a chunk of data from a file in GridFS.
    #
    # @param [ String ] key The identifier for the file.
    # @param [ Range ] range The range of bytes to download.
    # @return [ String ] The requested chunk of file data.
    def download_chunk(key, range)
      instrument :download_chunk, key: key, range: range do
        @fs_bucket.open_download_stream_by_name(key) do |stream|
          all_data = stream.read
          return all_data[range.first, range.size]
        end
      end
    end

    # Deletes a file from GridFS.
    #
    # @param [ String ] key The identifier for the file.
    def delete(key)
      instrument :delete, key: key do
        file = @fs_bucket.find( filename: key ).first
        @fs_bucket.delete(file[:_id]) if file
      end
    end

    # Deletes files in GridFS with a filename prefix.
    #
    # @param [ String ] prefix The prefix used to identify files.
    def delete_prefixed(prefix)  
      instrument :delete_prefixed, prefix: prefix do  
        @fs_bucket.find(filename: { "$regex" => /^#{Regexp.escape(prefix)}/ }).each do |file|  
          @fs_bucket.delete(file[:_id])  
        end  
      end  
    end

    # Checks if a file exists in GridFS.
    #
    # @param [ String ] key The identifier for the file.
    # @return [ Boolean ] True if the file exists, false otherwise.
    def exist?(key)
      instrument :exist, key: key do |payload|
        answer = @fs_bucket.find(filename: key).count > 0
        payload[:exist] = answer
        answer
      end
    end

    # Generates a private URL for accessing a file.
    #
    # @param [ String ] key The identifier for the file.
    # @param [ Integer ] expires_in The expiration time for the URL in seconds.
    # @param [ String ] filename The filename for the file.
    # @param [ String ] content_type The content type of the file.
    # @param [ String ] disposition The content disposition of the file.
    # @param **options Any additional options.
    # @return [ String ] The generated URL.
    def private_url(key, expires_in:, filename:, content_type:, disposition:, **)
      generate_url(key, expires_in: expires_in, filename: filename, content_type: content_type, disposition: disposition)
    end

    # Generates a public URL for accessing a file.
    #
    # @param [ String ] key The identifier for the file.
    # @param [ String ] filename The filename for the file.
    # @param [ String ] content_type The content type of the file.
    # @param [ Symbol ] disposition The content disposition of the file (default :attachment).
    # @param **options Any additional options.
    # @return [ String ] The generated URL.
    def public_url(key, filename:, content_type: nil, disposition: :attachment, **)
      generate_url(key, expires_in: nil, filename: filename, content_type: content_type, disposition: disposition)
    end

    # Redirect to public or private url functions.
    #
    # @param [ String ] key The identifier for the file.
    # @param **options Any additional options.
    # @return [ String ] The generated URL.
    def url(key, **options)
      super
    rescue NotImplementedError, ArgumentError
      if @public
        public_url(key, **options)
      else
        private_url(key, **options)
      end
    end

    # Generates the URL for accessing file.
    #
    # @param [ String ] key The identifier for the file.
    # @param [ Integer ] expires_in The expiration time for the upload in seconds.
    # @param [ String ] filename The filename for the file.
    # @param [ String ] content_type The content type of the file.
    # @param [ Symbol ] disposition The content disposition of the file (default :attachment).
    # @return [ String ] The URL for direct upload.
    def generate_url(key, expires_in:, filename:, disposition:, content_type:)
      instrument :url, key: key do |payload|
        content_disposition = content_disposition_with(type: disposition, filename: filename)
        verified_key_with_expiration = ActiveStorage.verifier.generate(
          {
            key: key,
            disposition: content_disposition,
            content_type: content_type
          },
          expires_in: expires_in,
          purpose: :blob_key
        )

        generated_url = url_helpers.rails_gridfs_service_url(verified_key_with_expiration,
                                                                **url_options,
                                                                disposition: content_disposition,
                                                                content_type: content_type,
                                                                filename: filename
        )
        payload[:url] = generated_url

        generated_url
      end
    end

    # Generates the URL for direct uploading.
    #
    # @param [ String ] key The identifier for the file.
    # @param [ Integer ] expires_in The expiration time for the upload in seconds.
    # @param [ String ] content_type The content type of the file.
    # @param [ Integer ] content_length The expected length of the content.
    # @param [ String ] checksum The checksum of the content (for verification).
    # @param [ Hash ] custom_metadata Any additional metadata.
    # @return [ String ] The URL for direct upload.
    def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:, custom_metadata: {})
      instrument :url, key: key do |payload|
        verified_token_with_expiration = ActiveStorage.verifier.generate(
          {
            key: key,
            content_type: content_type,
            content_length: content_length,
            checksum: checksum
          },
          expires_in: expires_in,
          purpose: :blob_token
        )

        generated_url = url_helpers.rails_gridfs_service_url(verified_token_with_expiration, **url_options)

        payload[:url] = generated_url

        generated_url
      end
    end

    # Returns the current GridFS bucket.
    #
    # @return [ Mongo::Grid::FSBucket ] The GridFS bucket instance.
    def bucket
      @fs_bucket
    end

    protected

    # Retrieves the URL helpers for constructing URL paths.
    #
    # @return [ Object ] The URL helpers object.
    def url_helpers
      @url_helpers ||= Rails.application.routes.url_helpers
    end

    # Provides relevant URL options.
    #
    # @return [ Hash ] The URL options, including the current host.
    def url_options
      if ActiveStorage::Current.respond_to?(:url_options)
        ActiveStorage::Current.url_options
      else
        { host: ActiveStorage::Current.host }
      end
    end
  end
end
