require "test_helper"  
  
module ActiveStorage
  module Gridfs  
    class GridfsControllerTest < ActionDispatch::IntegrationTest  
      test "POST update returns success" do  
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new("Hello, GridFS!"),
          filename: "greeting.txt",
          content_type: "text/plain"
        )  
        token = ActiveStorage.verifier.generate(
          { key: blob.key, checksum: blob.checksum, content_type: blob.content_type, content_length: blob.byte_size },
          purpose: :blob_token
        )  
  
        put update_rails_gridfs_service_path(encoded_token: token), params: "Hello, GridFS!", headers: { "Content-Type" => "text/plain" }  
  
        assert_response :no_content  
        assert_equal "Hello, GridFS!", blob.download
      end  

      test "GET show returns file content" do  
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new("Hello, GridFS!"),
          filename: "greeting.txt",
          content_type: "text/plain"
        )  
        key = ActiveStorage.verifier.generate(
          { key: blob.key, disposition: "attachment; filename=\"greeting.txt\"", content_type: blob.content_type },
          purpose: :blob_key
        )  
  
        get rails_gridfs_service_path(encoded_key: key, filename: "greeting.txt")  
  
        assert_response :success  
        assert_equal "Hello, GridFS!", @response.body  
        assert_equal blob.content_type, @response.headers["Content-Type"]  
      end
    end  
  end
end  
