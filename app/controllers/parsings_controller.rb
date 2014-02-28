class ParsingsController < ApplicationController

  def index
    @shop=Shop.all
  end

  def get_catalogs
    @parser=Parser.new
    @parser.get_catalogs(params[:id])
    @catalogs=CatalogShop.where(:shop_id => params[:id])
    respond_to do |format|
      format.html # index.html.erb
      format.json  { render :json => { :catalogs=>@cats.map{|x| {
                                           :id=>x.id,
                                           :title=>x.title,
                                           :count=>Product.where(:catalog_shop_id => x.id).size
                                       }}}}
    end
  end

  def get_goods
    @parser=Parser.new
    catalogs=params[:catalogs]
    @sh=Shop.find(params[:id])
    @cats=CatalogShop.where(:id=>catalogs)
    @cats=@sh.catalog_shops unless @cats.any?

    if @sh.title.include? 'Rekantino'
      @parser.get_rekantino(@cats)
    elsif @sh.title.include? 'Lala-style'
      @parser.get_lala_style(@cats)
    elsif @sh.title.include? 'Arabella'
      @parser.get_arabella(@cats)
    elsif @sh.title.include? 'Mix-mode'
      @parser.get_mix_mode(@cats)
    elsif @sh.title.include? "Yulia.prom.ua"
      @parser.get_yulia_prom(@cats)
    elsif @sh.title.include? "Rawjeans"
      @parser.get_rawjeans(@cats)
    elsif @sh.title.include? "Noch-sorochki"
      @parser.get_noch_sorochki(@cats)
    elsif @sh.title.include? "Deniliz"
      @parser.get_deniliz(@cats)
    end
    #render :json => @cats
    count_download=3
    respond_to do |format|
      format.html # index.html.erb
      format.json  { render :json => { :time => time,
                                       :catalogs=>@cats.map{|x| {
                                           :id=>x.id,
                                           :title=>x.title,
                                           :count=>Product.where(:catalog_shop_id => x.id).size
                                       }}}}
    end
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
