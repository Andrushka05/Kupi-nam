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
      page = Nokogiri::HTML(open(catalog.url).read)
      page.remove_namespaces!
      catalog_title=catalog.title
      #link to goods
      links=get_links(page,"//a[contains(concat(' ', @class, ' '), 'prod_more')]",@shop.host)
      #pages
      page.xpath("//div[contains(concat(' ', @class, ' '), 'shop2-pageist')]/a").map{ |link|
        if link.to_s.include? 'href'
          l=link['href']
          l=@shop.host+l unless l.include? @shop.host
          html=Nokogiri::HTML(open(l).read)
          get_links(html,"//a[contains(concat(' ', @class, ' '), 'prod_more')]",@shop.host).map{|x|
            links << x
          }
        end
      }
      links=links.compact.uniq
      #get full info goods
      links.each{  |link|
        html=Nokogiri::HTML(open(link).read)
        @goods=@shop.products.where(url:link).first_or_create
        if @goods.catalog_shop_id.nil?
          @goods.catalog_shop_id=catalog.id
        end

        @goods.title=get_node_text(html,"//div[contains(concat(' ', @class, ' '), 'product-right-bar')]/h1")
        code=get_node_text(html,"//div[contains(concat(' ', @class, ' '), 'product-code')]/span")
        @goods.article=code.strip
        code=get_node_text(html,"//div[contains(concat(' ', @class, ' '), 'product-code')]")
        @goods.color=code.slice(code.rindex("цвет:")+5,code.length-code.rindex("цвет:")-5).strip  if code.include? "цвет:"
        #price
        @price=Price.where(:product_id => @goods.id).first_or_create
        @price.cost= html.xpath("//div[contains(concat(' ', @class, ' '), 'product-accessory-prise')][1]").select{|x| x.text.include? "руб"}.collect {|node| node.text.gsub(/[^\d]/, '').to_f}.first
        @price.save
        #@goods.prices.where(@price).first_or_create
        desc=html.xpath("//div[contains(concat(' ', @id, ' '), 'tabs-1')]/p").collect {|node| node.text.strip}.join('\n')

        @goods.category_path=catalog_title
        if !desc.index("Размерный ряд модели").nil? && !desc.index("Цвета").nil?
          size=desc[desc.index("Размерный ряд модели")+21,desc.index("Цвета")-desc.index("Размерный ряд модели")-21].strip
          desc=desc[0,desc.index("Размерный ряд модели")]
          @goods.size=size.gsub(",","; ").gsub(".","")
        elsif !desc.index("Размерный ряд модели").nil?
          size=desc[desc.index("Размерный ряд модели")+21,desc.length-desc.index("Размерный ряд модели")-21].strip
          desc=desc[0,desc.index("Размерный ряд модели")]
          @goods.size=size.gsub(",","; ").gsub(".","")
        end
        @goods.description=desc
        images=html.xpath("//a[contains(concat(' ', @class, ' '), 'highslide')]").collect{|node| if node.nil? || node.attr('href').nil?
                                                                                                    nil
                                                                                                  elsif !(node.attr('href').include? @shop.host)
                                                                                                    @shop.host+node.attr('href')
                                                                                                  else
                                                                                                    node.attr('href')
                                                                                                  end }
        html.xpath("//div[contains(concat(' ', @class, ' '), 'product-thumbnails-wrap')]/ul/li/img").collect{|node|
          str=node.attr('onclick')
          str=str[str.index("this,")+5,str.index(",",str.index("this,")+5)-str.index("this,")-5].gsub!("'","").strip!
          if !str.include? @shop.host
            images << @shop.host+str
          else
            images << str
          end
        }

        images.uniq!
        images.map{ |x|
          Photo.where(:product_id => @goods.id, :url => x).first_or_create if x.length>0
        }
        @goods.save

        links2=html.xpath("//div[contains(concat(' ', @class, ' '), 'product-accessory-name')]/a").map{|x|
          unless x.attr('href').equal? link
            unless x.attr('href').include? @shop.host
              @shop.host+x.attr('href')
            else
              x.attr('href')
            end
          end
        }
        links2.map{|l|
          html2=Nokogiri::HTML(open(l).read)
          @goods2=@shop.products.where(url:l).first_or_create
          if @goods2.catalog_shop_id.nil?
            @goods2.catalog_shop_id=@goods.catalog_shop_id
          end

          @goods2.title=get_node_text(html2,"//div[contains(concat(' ', @class, ' '), 'product-right-bar')]/h1")
          code2=get_node_text(html2,"//div[contains(concat(' ', @class, ' '), 'product-code')]/span")
          @goods2.article=code2.strip
          code2=get_node_text(html2,"//div[contains(concat(' ', @class, ' '), 'product-code')]")
          @goods2.color=code2.slice(code2.index("цвет:")+5,code2.length-code2.index("цвет:")-5).strip if code2.include? "цвет:"
          #price
          @price2=Price.where(:product_id => @goods2.id).first_or_create
          @price2.cost= html2.xpath("//div[contains(concat(' ', @class, ' '), 'product-accessory-prise')][1]").select{|x|
            x.text.include? "руб"}.collect {|node| node.text.gsub(/[^\d]/, '').to_f
          }.first
          if @price2.cost.nil?
            @price2.cost=0
          end
          @price2.save
          #@goods.prices.where(@price).first_or_create
          desc2=html2.xpath("//div[contains(concat(' ', @id, ' '), 'tabs-1')]/p").collect {|node| node.text.strip}.join('\n')

          @goods2.category_path=catalog_title
          if !desc2.index("Размерный ряд модели").nil? && !desc2.index("Цвета").nil?
            size2=desc2[desc2.index("Размерный ряд модели")+21,desc2.index("Цвета")-desc2.index("Размерный ряд модели")-21].strip
            desc2=desc2[0,desc2.index("Размерный ряд модели")]
            @goods2.size=size2.gsub(",","; ").gsub(".","")
          elsif !desc2.index("Размерный ряд модели").nil?
            size2=desc2[desc2.index("Размерный ряд модели")+21,desc2.length-desc2.index("Размерный ряд модели")-21].strip
            desc2=desc2[0,desc2.index("Размерный ряд модели")]
            @goods2.size=size2.gsub(",","; ").gsub(".","")
          end
          @goods2.description=desc2
          images3=html.xpath("//a[contains(concat(' ', @class, ' '), 'highslide')]").collect{|node| if node.nil? || node.attr('href').nil?
                                                                                                             nil
                                                                                                           elsif !(node.attr('href').include? @shop.host)
                                                                                                             @shop.host+node.attr('href')
                                                                                                           else
                                                                                                             node.attr('href')
                                                                                                           end }
          html2.xpath("//div[contains(concat(' ', @class, ' '), 'product-thumbnails-wrap')]/ul/li/img").collect{|node|
            str=node.attr('onclick')
            str=str[str.index("this,")+5,str.index(",",str.index("this,")+5)-str.index("this,")-5].gsub!("'","").strip!
            if !str.include? @shop.host
              images3 << @shop.host+str
            else
              images3 << str
            end
          }
          images3.uniq!
          images3.map{ |x| Photo.where(:product_id => @goods.id, :url => x).first_or_create if x.length>0 }
          @goods2.save
        }
        sleep(1)
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
    return html.xpath(xpath).collect {|node| node.text.strip unless node.text.nil? }.first
  end
end