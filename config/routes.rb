Rails.application.routes.draw do
  devise_for :users, skip: [:passwords]

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  resources :assets, only: [:index]

  root "home#index"
end

