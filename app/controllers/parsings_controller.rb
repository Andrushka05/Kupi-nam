class ParsingsController < ApplicationController

  def index
    @shop=Shop.all
  end

  def get_catalog
    @parser=Parser.new
    @parser.get_catalogs(params[:id])
  end

  def get_goods
    @parser=Parser.new
    if @sh.title.include? 'Rekantino'
        @parser.get_rekantino(params[:id])
    end
    redirect_to shops_path
  end

end
