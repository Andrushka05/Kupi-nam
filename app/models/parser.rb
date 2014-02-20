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
    @shop.catalog_shops.map{|catalog|
        page = Nokogiri::HTML(open(catalog.url))

      #link to goods
      links=[]
      #find goods of catalog
      page.xpath("//a[contains(concat(' ', @class, ' '), 'good_list_item_img')]").each{
          |c| link=c.attr('href')
        unless link.include? @shop.host
          link=@shop.host+link
        end
        links << link
      }
      #get full info goods
      links.each{  |link|
        html=Nokogiri::HTML(open(link))
        @goods=@shop.products.where(url:link).first_or_create
        if @goods.catalog_shop_id.nil?
          @goods.catalog_shop_id=catalog.id
        end
        #@pr.nil? ? @goods=@shop.products.new : @goods=@pr

        @goods.title=html.xpath("//div[contains(concat(' ', @class, ' '), 'product_description_title')]").collect {|node| node.text.strip}.first
        @goods.article=html.xpath("//span[contains(concat(' ', @class, ' '), 'article')]").collect {|node| node.text.strip}.first
        #price
        @price=Price.where(:product_id => @goods.id).first_or_create
        @price.cost= html.xpath("//div[contains(concat(' ', @class, ' '), 'product_description_row')]/span").select{|x| x.text.include? "руб"}.collect {|node| node.text.strip.sub('-','.').to_f}.first
        @price.save
        #@goods.prices.where(@price).first_or_create
        desc=html.xpath("//div[contains(concat(' ', @class, ' '), 'product_description_row')]/p").collect {|node| node.text.strip}
        @goods.description=desc.select{|x| !x.nil? && x.length>0}.join('\n')
        cat=html.xpath("//div[contains(concat(' ', @class, ' '), 'bread_crumb_big')]/a").collect {|node| unless node.text.include? 'Каталог'
                                                                                                           node.text.strip
                                                                                                         end }
        @goods.category_path=cat.select{|x| x!=nil}.join('/')
        size=html.xpath("//select[contains(concat(' ', @id, ' '), 'size')]/option").collect {|node| unless node.text.include? 'размер'
                                                                                                           node.text.strip
                                                                                                    end }
        @goods.size=size.select{|x| x!=nil}.join('; ')
        images=html.xpath("//a[contains(concat(' ', @class, ' '), 'cloud-zoom')]").collect{|node| if node.nil? || node.attr('href').nil?
                                                                                                    nil
                                                                                                  elsif !(node.attr('href').include? @shop.host)
                                                                                                    @shop.host+node.attr('href')
                                                                                                  else
                                                                                                    node.attr('href')
                                                                                                  end }
        images.select{|x| x!=nil}.each{ |x| Photo.where(:product_id => @goods.id, :url => x).first_or_create }

        @goods.color=''
        @goods.save

        #@cat.products.where(goods).first_or_create
      }
    }
  end

  def save_xls(id)

  end


end