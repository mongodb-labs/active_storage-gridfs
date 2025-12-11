Rails.application.routes.draw do
  # Active Storage GridFS routes are automatically loaded from the engine
  # Add routes for creating and showing posts to test engine functionality
  resources :posts, only: [:create, :new, :show, :edit, :update, :destroy]
end
