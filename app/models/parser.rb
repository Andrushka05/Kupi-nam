require 'open-uri'
require 'nokogiri'

class Parser
  def get_catalogs (id)
    @shop=Shop.find(id)
    page = Nokogiri::HTML(open(@shop.url))
    #find catalogs
    page.xpath(@shop.xpath).each{
      |c| link=c.attr('href')
      unless link.include? @shop.host
        link=@shop.host+link
      end
      @shop.catalog_shops.where(title: c.text, url: link).first_or_create
    }
  end

  def get_rekantino (id)
    @shop=Shop.find(id)
    @catalog=@shop.catalog_shops.find(id)
    page = Nokogiri::HTML(open(@catalog.url))
    #link to goods
    links=[]
    #find goods of catalog
    page.xpath("//a[contains(concat(' ', @class, ' '), 'good_list_item_img')]").each{
        |c| link=c.attr('href')
      unless link.include? sh.host
        link=sh.host+link
      end
      links << link
    }
    #get full info goods
    links.each{  |link|
      html=Nokogiri::HTML(open(link))
      goods=Product.new

      goods.title=html.xpath("//div[contains(concat(' ', @class, ' '), 'product_description_title')]").collect {|node| node.text.strip}.first
      goods.article=html.xpath("//span[contains(concat(' ', @class, ' '), 'article')]").collect {|node| node.text.strip}.first
      #price
      price=Price.new
      price.cost= html.xpath("//div[contains(concat(' ', @class, ' '), 'product_description_row')]/span").collect {|node| node.text.strip}.first
      goods.prices.where(price).first_or_create
      desc=html.xpath("//div[contains(concat(' ', @class, ' '), 'product_description_row')]/p").collect {|node| node.text.strip}
      goods.description=desc.join('\r\n')
      cat=html.xpath("//div[contains(concat(' ', @class, ' '), 'bread_crumb_big')]/a").collect {|node| unless node.text.include? 'Каталог'
                                                                                                         node.text.strip
                                                                                                       end }
      goods.category_path=cat.select{|x| x!=nil}.join('/')
      size=html.xpath("//select[contains(concat(' ', @id, ' '), 'size')]/option").collect {|node| unless node.text.include? 'размер'
                                                                                                         node.text.strip
                                                                                                  end }
      goods.size=size.select{|x| x!=nil}.join('; ')
      images=html.xpath("//a[contains(concat(' ', @class, ' '), 'cloud-zoom')]").collect{|node| unless node.attr('href').include? sh.host
                                                                                                  sh.host+node.attr('href')
                                                                                                else
                                                                                                  node.attr('href')
                                                                                                end }
      images.each{|x| photo=Photo.new
        photo.url=x
        goods.photos.where(photo).first_or_create
      }
      goods.color=''
      @catalog.products.where(goods).first_or_create
    }
  end

  def save_xls(id)

  end


end