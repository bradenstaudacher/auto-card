Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  mount ActionCable.server => "/cable"

  namespace :api do
    namespace :v1 do
      post "coop", to: "coop#create"
      post "coop/join", to: "coop#join"

      # Content brainstorm board (public/board.html)
      resources :drafts, only: %i[index create update destroy] do
        post :promote, on: :collection
      end

      resources :runs, only: %i[create show] do
        resources :placements, only: %i[create]
        resources :rewards, only: [] do
          post :select, on: :member
        end
        resources :player_cards, only: %i[destroy] do
          member do
            post :assign
            post :unassign
          end
          patch :reorder, on: :collection
        end
        resources :player_characters, only: [] do
          patch :ability_order, on: :member
        end
      end
    end
  end
end
