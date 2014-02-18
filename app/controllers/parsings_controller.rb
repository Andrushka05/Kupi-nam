class ParsingsController < ApplicationController

  def index
    @shop=Shop.all
  end


end
