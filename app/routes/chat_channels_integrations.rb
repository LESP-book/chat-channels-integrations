# frozen_string_literal: true

require_dependency "admin_constraint"

ChatChannelsIntegrations::AdminEngine.routes.draw do
  get "/rules" => "admin/rules#index"
  post "/rules" => "admin/rules#create"
  put "/rules/:id" => "admin/rules#update"
  delete "/rules/:id" => "admin/rules#destroy"
end
