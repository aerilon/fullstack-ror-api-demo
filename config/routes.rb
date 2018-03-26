Rails.application.routes.draw do
  namespace :v1 do
    resources :product, only: [:create] # TODO: :destroy & :update
    resource :products, only: [:show]
  end
end
