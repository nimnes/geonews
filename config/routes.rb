Geonews::Application.routes.draw do

    put "/news/:id", to: 'news#update'
    get "/news", to: 'news#index'

    root to: 'static_pages#home'

    match '/lemmatizer',  to: 'static_pages#lemmatizer'
    match '/help',        to: 'static_pages#help'
    match '/about',       to: 'static_pages#about'
    match '/contact',     to: 'static_pages#contact'
    match '/normalize',   to: 'static_pages#normalize'
end
