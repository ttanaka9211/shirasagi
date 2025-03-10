Rails.application.routes.draw do

  Opendata::Initializer

  concern :deletion do
    get :delete, on: :member
    delete :destroy_all, on: :collection, path: ''
  end

  concern :command do
    get :command, on: :member
    post :command, on: :member
  end

  concern :change_state do
    get :state, on: :member
    put :change_state_all, on: :collection, path: ''
  end

  content "opendata" do
    resources :ideas, concerns: [:deletion, :command, :change_state], module: :idea do
      resources :comments, concerns: :deletion do
        match :soft_delete, on: :member, via: [:get, :post]
        match :undo_delete, on: :member, via: [:get, :post]
      end
    end
    resources :idea_categories, concerns: :deletion, module: :idea
    resources :search_ideas, concerns: :deletion, module: :idea
  end

  node "opendata" do
    get "idea_category/" => "public#index", cell: "nodes/idea/idea_category"
    get "idea_category/rss.xml" => "public#rss", cell: "nodes/idea/idea_category"
    get "idea_category/:name/" => "public#index", cell: "nodes/idea/idea_category"
    get "idea_category/:name/rss.xml" => "public#rss", cell: "nodes/idea/idea_category"
    # get "idea_category/:name/areas" => "public#index_areas", cell: "nodes/idea/idea_category"
    # get "idea_category/:name/tags" => "public#index_tags", cell: "nodes/idea/idea_category"

    get "idea/(index.:format)" => "public#index", cell: "nodes/idea/idea"
    get "idea/rss.xml" => "public#rss", cell: "nodes/idea/idea"
    get "idea/areas" => "public#index_areas", cell: "nodes/idea/idea"
    get "idea/tags" => "public#index_tags", cell: "nodes/idea/idea"
    get "idea/:idea/point.:format" => "public#show_point", cell: "nodes/idea/idea", format: false
    post "idea/:idea/point.:format" => "public#add_point", cell: "nodes/idea/idea", format: false
    get "idea/:idea/point/members.html" => "public#point_members", cell: "nodes/idea/idea", format: false
    get "idea/:idea/comment/show.:format" => "public#index", cell: "nodes/idea/comment", format: false
    post "idea/:idea/comment/add.:format" => "public#add", cell: "nodes/idea/comment", format: false
    post "idea/:idea/comment/delete.:format" => "public#delete", cell: "nodes/idea/comment", format: false
    get "idea/:idea/dataset/show.:format" => "public#show_dataset", cell: "nodes/idea/idea", format: false
    get "idea/:idea/app/show.:format" => "public#show_app", cell: "nodes/idea/idea", format: false

    match "search_idea/(index.:format)" => "public#index", cell: "nodes/idea/search_idea", via: [:get, :post]
    get "search_idea/tags" => "public#index_tags", cell: "nodes/idea/search_idea"
    get "search_idea/search" => "public#search", cell: "nodes/idea/search_idea"
    get "search_idea/rss.xml" => "public#rss", cell: "nodes/idea/search_idea"
  end

  part "opendata" do
    get "idea" => "public#index", cell: "parts/idea/idea"
  end

  page "opendata" do
    get "idea/:filename.:format" => "public#index", cell: "pages/idea/idea"
  end
end
