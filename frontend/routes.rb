ArchivesSpace::Application.routes.draw do
  match('/plugins/alma_integrations' => 'alma_integrations#index', :via => [:get])
  match('/plugins/alma_integrations/search' => 'alma_integrations#search', :via => [:post])
  match('/plugins/alma_integrations/add_bibs' => 'alma_integrations#add_bibs', :via => [:post])
  match('/plugins/alma_integrations/add_holdings' => 'alma_integrations#add_holdings', :via => [:post])
end
