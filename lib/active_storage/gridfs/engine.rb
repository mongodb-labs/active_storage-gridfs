require "active_storage/engine"
module ActiveStorage
  module Gridfs
    class Engine < ::Rails::Engine
      isolate_namespace ActiveStorage::Gridfs

      railtie_name 'active_storage_gridfs'
    end
  end
end




