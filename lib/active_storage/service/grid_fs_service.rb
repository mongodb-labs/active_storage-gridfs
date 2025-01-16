# frozen_string_literal: true

module ActiveStorage
  class Service::GridFSService < Service

    def initialize(database:, uri:, bucket: "fs", **options)
      @client = Mongo::Client.new(uri, { database: database })
      @fs_bucket = Mongo::Grid::FSBucket.new(@client.database, bucket_name: bucket)
    end

    def upload(key, io, checksum: nil, **options)
      instrument :upload, key: key, checksum: checksum do
        blob = ActiveStorage::Blob.find_by(key: key)
        metadata = { original_filename: blob.filename.to_s }
        metadata.merge!(options[:metadata]) if options[:metadata].present?
        @fs_bucket.upload_from_stream(key, io, metadata: metadata)
      end
    end

    def download(key)
      instrument :download, key: key do
        @fs_bucket.open_download_stream_by_name(key) do |stream|
          return stream.read
        end
      end
    end

    def download_chunk(key, range)
      instrument :download_chunk, key: key, range: range do
        @fs_bucket.open_download_stream_by_name(key) do |stream|
          all_data = stream.read
          return all_data[range.first, range.size]
        end
      end
    end

    def delete(key)
      instrument :delete, key: key do
        file = @fs_bucket.find( filename: key ).first
        @fs_bucket.delete(file[:_id]) if file
      end
    end

    def delete_prefixed(prefix)  
      instrument :delete_prefixed, prefix: prefix do  
        @fs_bucket.find(filename: { "$regex" => /^#{Regexp.escape(prefix)}/ }).each do |file|  
          @fs_bucket.delete(file[:_id])  
        end  
      end  
    end

    def exist?(key)
      instrument :exist, key: key do |payload|
        answer = @fs_bucket.find(filename: key).count > 0
        payload[:exist] = answer
        answer
      end
    end

    def private_url(key, expires_in:, filename:, content_type:, disposition:, **)
      generate_url(key, expires_in: expires_in, filename: filename, content_type: content_type, disposition: disposition)
    end

    def public_url(key, filename:, content_type: nil, disposition: :attachment, **)
      generate_url(key, expires_in: nil, filename: filename, content_type: content_type, disposition: disposition)
    end

    def url(key, **options)
      super
    rescue NotImplementedError, ArgumentError
      if @public
        public_url(key, **options)
      else
        private_url(key, **options)
      end
    end

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

    def bucket
      @fs_bucket
    end

    protected

    def url_helpers
      @url_helpers ||= Rails.application.routes.url_helpers
    end

    def url_options
      if ActiveStorage::Current.respond_to?(:url_options)
        ActiveStorage::Current.url_options
      else
        { host: ActiveStorage::Current.host }
      end
    end
  end
end
