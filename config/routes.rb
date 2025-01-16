# frozen_string_literal: true

Rails.application.routes.draw do
  get  "/rails/active_storage/gridfs/:encoded_key/*filename" => "active_storage/gridfs#show", as: :rails_gridfs_service
  put  "/rails/active_storage/gridfs/:encoded_token" => "active_storage/gridfs#update", as: :update_rails_gridfs_service
end