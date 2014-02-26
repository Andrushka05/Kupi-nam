KupiNam::Application.routes.draw do

  get "catalog_shops/index"
  get "parsings/index"
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'shops#index'
  resources :shops
  resources :parsings
  resources :catalog_shops
  # Example of regular route:
   #  get 'shops/:id' => 'shops#pars'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
     resources :parsings do
       member do
         post 'get_catalogs'
         post 'get_goods'
       end
  #
  #     collection do
  #       get 'sold'
  #     end
     end
    resources :save do
      member do
        post 'save_xls'
        post 'save_xlsx'
      end
    end
  # Example resource route with sub-resources:
     #resources :shops do
       #resources :products
       #resource :c
     #end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
