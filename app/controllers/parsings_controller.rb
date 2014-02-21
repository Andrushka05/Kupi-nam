class ParsingsController < ApplicationController

  def index
    @shop=Shop.all
  end

  def get_catalogs
    @parser=Parser.new
    @parser.get_catalogs(params[:id])
    redirect_to shops_path
  end

  def get_goods
    @parser=Parser.new
    @sh=Shop.find(params[:id])
    if @sh.title.include? 'Rekantino'
      @parser.get_rekantino(params[:id])
    elsif @sh.title.include? 'Lala-style'
      @parser.get_lala_style(params[:id])
    end
    redirect_to shop_path
  end

end
