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
    elsif @sh.title.include? 'Arabella'
      @parser.get_arabella(params[:id])
    elsif @sh.title.include? 'Mix-mode'
      @parser.get_mix_mode(params[:id])
    end
    elsif @sh.title.include? "Yulia.prom.ua"
      @parser.get_yulia_prom(params[:id])
    end
    redirect_to shop_path
  end

end
