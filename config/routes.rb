Rails.application.routes.draw do
  namespace :v1 do
    resources :product, only: [:create], :format => false # TODO: :destroy & :update
    resource :products, only: [:show], :format => false
  end
end
