require 'open-uri'
require 'nokogiri'

class Parser
  def init (id)
    @shop=Shop.find(id)
    page = Nokogiri::HTML(open(@shop.url))
    #find catalogs
    catalogs=Hash.new
    html=page.to_s
    page.xpath(@shop.xpath).each{
      |c| link=c.attr('href')
      unless link.include? @shop.host
        link=@shop.host+link
      end
      catalogs[c.text]=link
      @shop.catalog_shops.where(title: c.text, url: link).first_or_create
      puts 'Add -'+c.text

    }
  end

  def recant

  end


end