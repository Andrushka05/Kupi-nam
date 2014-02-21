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
        @price.cost= html.xpath("//div[contains(concat(' ', @class, ' '), 'product_description_row')]").select{|x| x.text.include? "руб"}.collect {|node| node.text.strip.gsub(/[^\d]/, '').to_f}.first
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

  def get_lala_style(id)
    @shop=Shop.find(id)
    @shop.catalog_shops.map{|catalog|
      page = Nokogiri::HTML(open(catalog.url))
      page.remove_namespaces!
      catalog_title=catalog.title
      #link to goods
      links=get_links(page,"//a[contains(concat(' ', @class, ' '), 'prod_more')]",@shop.host)
      #pages
      pages=page.xpath("//div[contains(concat(' ', @class, ' '), 'shop2-pageist')]/a").map{ |link|
        html=Nokogiri::HTML(open(link))
        links << get_links(html,"//a[contains(concat(' ', @class, ' '), 'prod_more')]",@shop.host)
      }
      links=links.compact.uniq
      #get full info goods
      links.each{  |link|
        html=Nokogiri::HTML(open(link))
        @goods=@shop.products.where(url:link).first_or_create
        if @goods.catalog_shop_id.nil?
          @goods.catalog_shop_id=catalog.id
        end

        @goods.title=get_node_text(html,"//div[contains(concat(' ', @class, ' '), 'product-right-bar')]/h1")
        code=get_node_text(html,"//div[contains(concat(' ', @class, ' '), 'product-code')]/span")
        @goods.article=code.slice(0,code.rindex("цвет:")).sub("Артикул:","").strip
        @goods.color=code.slice(code.rindex("цвет:")+5,code.length-code.rindex("цвет:")-5).strip
        #price
        @price=Price.where(:product_id => @goods.id).first_or_create
        @price.cost= html.xpath("//div[contains(concat(' ', @class, ' '), 'product-accessory-prise')][1]").select{|x| x.text.include? "руб"}.collect {|node| node.text.gsub(/[^\d]/, '').to_f}.first
        @price.save
        #@goods.prices.where(@price).first_or_create
        desc=html.xpath("//div[contains(concat(' ', @id, ' '), 'tabs-1')]/p").collect {|node| node.text.strip}
        @goods.description=desc.select{|x| !x.nil? && x.length>0}.join('\n')
        @goods.category_path=catalog_title
        size=desc.slice(desc.index("Размерный ряд модели")+21,desc.index("Цвета:")-desc.index("Размерный ряд модели")-21).strip
        desc.slice!(0,"Размерный ряд модели")
        @goods.size=size.compact.join('; ')
        images=html.xpath("//a[contains(concat(' ', @class, ' '), 'highslide')]").compact.collect{|node| if node.nil? || node.attr('href').nil?
                                                                                                    nil
                                                                                                  elsif !(node.attr('href').include? @shop.host)
                                                                                                    @shop.host+node.attr('href')
                                                                                                  else
                                                                                                    node.attr('href')
                                                                                                  end }
        images2=html.xpath("//div[contains(concat(' ', @class, ' '), 'product-thumbnails-wrap')]/ul/li/img").compact.collect{|node|
          str=node.attr('onclick')
          str.slice!(str.index("this,")+5,str.index(",",str.index("this,")+5)-str.index("this,")-5).gsub!("'","").strip!
          if !str.include? @shop.host
            @shop.host+str
          else
            str
          end
        }
        images << images2
        images.uniq.compact.map{ |x| Photo.where(:product_id => @goods.id, :url => x).first_or_create }
        @goods.save

        links2=html.xpath("//div[contains(concat(' ', @class, ' '), 'product-accessory-name')]/a").compact.select{|x|
          unless x.attr('href').equal? link
            unless x.attr('href').include? @shop.host
              @shop.host+node.attr('href')
            else
              node.attr('href')
            end
          end
        }.uniq
        links2.map{|l|
          html2=Nokogiri::HTML(open(l))
          @goods2=@shop.products.where(url:l).first_or_create
          if @goods2.catalog_shop_id.nil?
            @goods2.catalog_shop_id=@goods.catalog_shop_id
          end

          @goods2.title=get_node_text(html2,"//div[contains(concat(' ', @class, ' '), 'product-right-bar')]/h1")
          code2=get_node_text(html2,"//div[contains(concat(' ', @class, ' '), 'product-code')]/span")
          @goods2.article=code2.slice(0,code2.index("цвет:")).sub("Артикул:","").strip
          @goods2.color=code2.slice(code2.index("цвет:")+5,code2.length-code2.index("цвет:")-5).strip
          #price
          @price2=Price.where(:product_id => @goods.id).first_or_create
          @price2.cost= html2.xpath("//div[contains(concat(' ', @class, ' '), 'product-accessory-prise')][1]").select{|x| x.text.include? "руб"}.collect {|node| node.text.gsub(/[^\d]/, '').to_f}.first
          @price2.save
          #@goods.prices.where(@price).first_or_create
          desc2=html2.xpath("//div[contains(concat(' ', @id, ' '), 'tabs-1')]/p").collect {|node| node.text.strip}
          @goods2.description=desc2.select{|x| !x.nil? && x.length>0}.join('\n')
          @goods2.category_path=catalog_title
          size2=desc.slice(desc2.index("Размерный ряд модели")+21,desc2.index("Цвета:")-desc2.index("Размерный ряд модели")-21).strip
          desc2.slice!(0,"Размерный ряд модели")
          @goods2.size=size2.compact.join('; ')
          images3=html.xpath("//a[contains(concat(' ', @class, ' '), 'highslide')]").compact.collect{|node| if node.nil? || node.attr('href').nil?
                                                                                                             nil
                                                                                                           elsif !(node.attr('href').include? @shop.host)
                                                                                                             @shop.host+node.attr('href')
                                                                                                           else
                                                                                                             node.attr('href')
                                                                                                           end }
          images4=html.xpath("//div[contains(concat(' ', @class, ' '), 'product-thumbnails-wrap')]/ul/li/img").compact.collect{|node|
            str=node.attr('onclick')
            str.slice!(str.index("this,")+5,str.index(",",str.index("this,")+5)-str.index("this,")-5).gsub!("'","").strip!
            if !str.include? @shop.host
              @shop.host+str
            else
              str
            end
          }
          images3 << images4
          images3.uniq.compact.map{ |x| Photo.where(:product_id => @goods.id, :url => x).first_or_create }
          @goods2.save
        }
      }
    }
  end


  private
  # @param [Nokogiri] html
  # @param [string] xpath
  # @param [string] host
  def get_links(html,xpath,host)
      links=[]
      html.xpath(xpath).map{
          |c| link=c.attr('href')
        unless link.include? host
          link=host+link
        end
        links << link
      }

      return links.compact.uniq
  end

  private
  # @param [Nokogiri] html
  def get_node_text(html,xpath)
    return html.xpath(xpath).compact!.collect! {|node| node.text.strip}.first
  end
end