Rails.application.routes.draw do
  # Devise routes for users, including omniauth_callbacks for Google OAuth2
  # devise_for :users, controllers: { omniauth_callbacks: 'omniauth_callbacks' }

  # Optional: Custom routes (avoid conflicting with Devise)
  # If you need a custom sign-in route, make sure it's unique and doesn't conflict with Devise's default sign-in route.
  # get 'users/sign_in', to: 'sessions#new', as: 'custom_sign_in'  # REMOVE this line to avoid conflict with Devise's default route

  # Health check route (optional)
  get "up" => "rails/health#show", as: :rails_health_check

  # Define root path
  root to: 'home#index'
end
