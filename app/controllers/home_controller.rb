class HomeController < ApplicationController
  before_action :authenticate_user!, only: [:index]

  def index
    # Any logic for the index action goes here
  end
end
