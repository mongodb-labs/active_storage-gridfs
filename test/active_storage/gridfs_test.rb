# frozen_string_literal: true

require "active_storage/shared_service_tests"
require "mongo"
class ActiveStorage::Service::GridFSServiceTest < ActiveSupport::TestCase
  SERVICE  = ActiveStorage::Service.configure(:gridfs, {gridfs: {service: "GridFS", uri: "mongodb://localhost:27017", database: "sandbox"}})

  setup do
    if ActiveStorage::Current.respond_to?(:url_options=)
      ActiveStorage::Current.url_options = {host: "https://example.com", protocol: "https"}
    else
      ActiveStorage::Current.host = "https://example.com"
    end
  end

  teardown do
    ActiveStorage::Current.reset
  end

  include ActiveStorage::Service::SharedServiceTests
end
