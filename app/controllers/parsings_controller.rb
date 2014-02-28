class ParsingsController < ApplicationController

  def index
    @shop=Shop.all
  end

  def get_catalogs
    @parser=Parser.new
    @parser.get_catalogs(params[:id])
    @catalogs=CatalogShop.where(:shop_id => params[:id])
    render :json => @catalogs
  end

  def get_goods
    @parser=Parser.new
    fdsf=params[:catalogs]
    @sh=Shop.find(params[:id])
    if @sh.title.include? 'Rekantino'
      @parser.get_rekantino(params[:id])
    elsif @sh.title.include? 'Lala-style'
      @parser.get_lala_style(params[:id])
    elsif @sh.title.include? 'Arabella'
      @parser.get_arabella(params[:id])
    elsif @sh.title.include? 'Mix-mode'
      @parser.get_mix_mode(params[:id])
    elsif @sh.title.include? "Yulia.prom.ua"
      @parser.get_yulia_prom(params[:id])
    elsif @sh.title.include? "Rawjeans"
      @parser.get_rawjeans(params[:id])
    elsif @sh.title.include? "Noch-sorochki"
      @parser.get_noch_sorochki(params[:id])
    elsif @sh.title.include? "Deniliz"
      @parser.get_deniliz(params[:id])
    end
    redirect_to shop_path
  end
=begin
  def as_json(options={})
    super(:only => [:first_name,:last_name,:city,:state],
          :include => {
              :employers => {:only => [:title]},
              :roles => {:only => [:name]}
          }
    )
  end
=end
end
