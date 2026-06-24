Rails.application.routes.draw do

  resources :nilms, only: [:index, :show, :create, :update, :destroy]

  resources :data_views do
    collection do
      get 'home' #retrieve a user's home data view
      put 'map_joule_objects'
    end
  end

  resources :db_folders, only: [:show, :update]
  resources :db_streams, only: [:index, :update] do
    resources :annotations, except: [:show]
    member do
      post 'data'
    end
  end

  resources :db_elements, only: [:index] do
    collection do
      get 'data'
    end
  end

  resources :events, only: [:index, :show, :update] do
    collection do
      get 'data'
    end
  end
  # fix for devise invitable from:
  #http://gabrielhilal.com/2015/11/07/integrating-devise_invitable-into-devise_token_auth/
  mount_devise_token_auth_for 'User', at: 'auth', skip: ['invitations']
  devise_for :users, defaults: {format: :json}, path: "auth", only: [:invitations],
    controllers: { invitations: 'invitations' }

  resources :users, only: [:index] do
    collection do
      post 'auth_token'
    end
  end
  resources :user_groups, only: [:index, :update, :create, :destroy] do
    member do
      put 'create_member'
      put 'add_member'
      put 'invite_member'
      put 'remove_member'
    end
  end
  resources :permissions, only: [:index, :create, :destroy] do
    collection do
      put 'create_user'
      put 'invite_user'
    end
  end

  get 'app/:id/auth', to: 'proxy#authenticate'
  get 'app/:id.json', to: 'data_app#show'

  #get 'data_app/:id', to: 'data_app#get'
  #get 'data_app/:id/*path', to: 'data_app#get'
  #post 'data_app/:id/*path', to: 'data_app#post'

  get 'index', to: 'home#index'
  root to: 'home#index'


end
