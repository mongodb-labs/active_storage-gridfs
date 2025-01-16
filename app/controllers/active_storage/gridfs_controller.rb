# frozen_string_literal: true

class ActiveStorage::GridfsController < ActiveStorage::BaseController
  skip_forgery_protection

  def show
    if key = decode_verified_key
      response.headers["Content-Type"] = key["content_type"] || DEFAULT_SEND_FILE_TYPE
      response.headers["Content-Disposition"] = key["disposition"] || DEFAULT_SEND_FILE_DISPOSITION

      file_info = fs_bucket.find({ filename: key["key"] }).first
      file_size = file_info["length"]
      ranges = Rack::Utils.get_byte_ranges(request.get_header("HTTP_RANGE"), file_size)

      if ranges.nil? || ranges.length > 1
        self.status = :ok
        self.response_body = fs_service.download(key["key"])
      elsif ranges.empty?
        head 416, content_range: "bytes */#{file_size}"
      else
        range = ranges[0]
        self.status = :partial_content
        response.headers["Content-Range"] = "bytes #{range.begin}-#{range.end}/#{file_size}"
        self.response_body = fs_service.download_chunk(key["key"], range)
      end
    else
      head :not_found
    end
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def update
    if token = decode_verified_token
      if acceptable_content?(token)
        fs_service.upload token["key"], request.body, checksum: token["checksum"]
        head :no_content
      else
        head :unprocessable_entity
      end
    else
      head :not_found
    end
  rescue ActiveStorage::IntegrityError
    head :unprocessable_entity
  end

  private
  def fs_service
    ActiveStorage::Blob.service
  end

  def fs_bucket
    fs_service.bucket
  end

  def decode_verified_key
    ActiveStorage.verifier.verified(params[:encoded_key], purpose: :blob_key)
  end

  def decode_verified_token
    ActiveStorage.verifier.verified(params[:encoded_token], purpose: :blob_token)
  end

  def acceptable_content?(token)
    token["content_type"] == request.content_mime_type && token["content_length"] == request.content_length
  end
end
