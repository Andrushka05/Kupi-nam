require 'rubygems'
require 'open-uri'
require 'nokogiri'
require 'mechanize'

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
        @goods.description=desc.select{|x| !x.nil? && x.length>0}.join("\n")
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
      mechan = Mechanize.new { |agent|
        # Flickr refreshes after login
        agent.follow_meta_refresh = true
      }
      encoding =  'WINDOWS-1251' # 'UTF-8'
      page = Nokogiri::HTML(mechan.get(catalog.url).body,nil,encoding)
      page.remove_namespaces!
      catalog_title=catalog.title
      #link to goods
      links=get_links(page,"//a[contains(concat(' ', @class, ' '), 'prod_more')]",@shop.host)
      #pages
      page.xpath("//div[contains(concat(' ', @class, ' '), 'shop2-pageist')]/a").map{ |link|
        if link.to_s.include? 'href'
          l=link['href']
          l=@shop.host+l unless l.include? @shop.host
          html=Nokogiri::HTML(mechan.get(l).body)
          get_links(html,"//a[contains(concat(' ', @class, ' '), 'prod_more')]",@shop.host).map{|x|
            links << x
          }
        end
      }
      links=links.compact.uniq
      #get full info goods
      links.each{  |link|
        html=Nokogiri::HTML(mechan.get(link).body)
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
        desc=html.xpath("//div[contains(concat(' ', @id, ' '), 'tabs-1')]/p").collect {|node| node.text.strip}.join("\n")

        @goods.category_path=catalog_title
        if !desc.index("Размерный ряд модели").nil? && !desc.index("Цвет").nil?
          size=desc[desc.index("Размерный ряд модели")+21,desc.index("Цвет")-desc.index("Размерный ряд модели")-21]
          desc=desc[0,desc.index("Размерный ряд модели")]
          unless size.nil?
            if size.length>250
              size=size[0,size.downcase.index(@goods.color.downcase)]
            end
            @goods.size=size.gsub(",","; ").gsub(".","").strip
          end
        elsif !desc.index("Размерный ряд модели").nil?
          size=desc[desc.index("Размерный ряд модели")+21,desc.length-desc.index("Размерный ряд модели")-21]
          desc=desc[0,desc.index("Размерный ряд модели")]
          unless size.nil?
            if size.length>250
              ytr=@goods.color
              ss=size.upcase!
              z=ss.index(ytr)
              size=size[0,z]
            end
            @goods.size=size.gsub(",","; ").gsub(".","").strip
          end
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
          html2=Nokogiri::HTML(mechan.get(l).body)
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
          desc2=html2.xpath("//div[contains(concat(' ', @id, ' '), 'tabs-1')]/p").collect {|node| node.text.strip}.join("\n")

          @goods2.category_path=catalog_title
          if !desc2.index("Размерный ряд модели").nil? && !desc2.index("Цвет").nil?
            size2=desc2[desc2.index("Размерный ряд модели")+21,desc2.index("Цвет")-desc2.index("Размерный ряд модели")-21]
            desc2=desc2[0,desc2.index("Размерный ряд модели")]
            if !size2.nil?
              if size2.length>250
                size2=size2[0,size2.downcase.index(@goods2.color.downcase)]
              end
              @goods2.size=size2.gsub(",","; ").gsub(".","").strip
            end
          elsif !desc2.index("Размерный ряд модели").nil?
            size2=desc2[desc2.index("Размерный ряд модели")+21,desc2.length-desc2.index("Размерный ряд модели")-21]
            desc2=desc2[0,desc2.index("Размерный ряд модели")]
            if !size2.nil?
              if size2.length>250
                size2=size2[0,size2.downcase.index(@goods2.color.downcase)]
              end
              @goods2.size=size2.gsub(",","; ").gsub(".","").strip
            end
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

  def get_arabella(id)
    @shop=Shop.find(id)
    mechan = Mechanize.new { |agent|
      # Flickr refreshes after login
      agent.follow_meta_refresh = true
      #agent.page.encoding='WINDOWS-1251'
    }
    encoding = 'WINDOWS-1251'  # 'UTF-8'

    mechan.get(@shop.url){|p|
      log = p.form_with(:id => 'login_block__form'){ |form|
        form.email='Krasnoselskova@rambler.ru'
        form.password='123456'
      }.submit
    }
    mechan.get(@shop.url)
    @shop.catalog_shops.map{|catalog|
      mechan.get(catalog.url){|p|

      page = Nokogiri::HTML(p.body,nil,encoding) #+"?characteristics%5B%5D=1290270&page_size=100"
      page.remove_namespaces!
      catalog_title=catalog.title
      #link to goods
      ls=[]
      #p.parser.xpath("//p[contains(concat(' ', @class, ' '), 'title')]/a").map{|x|
        #ls << x
      #}
      links=get_links_pages_all(p.parser,"//p[contains(concat(' ', @class, ' '), 'title')]/a","//span[contains(concat(' ', @class, ' '), 'pagination_page')]/a",@shop.host,"page=")
      links=links.compact.uniq
      #get full info goods
      links.each{  |link|
        mechan.get(link){|pp2|

        @goods=@shop.products.where(url:link).first_or_create
        if @goods.catalog_shop_id.nil?
          @goods.catalog_shop_id=catalog.id
        end

        @goods.title=get_node_text(pp2.parser,"//table[contains(concat(' ', @class, ' '), 'prps')]/tr[1]").gsub("Товар:","").strip
        @goods.article=get_node_text(pp2.parser,"//div[contains(concat(' ', @class, ' '), 'fl prod-info')]/h1").strip
        @goods.color=""
        #price
        add_prices(pp2.parser,["//span[contains(concat(' ', @class, ' '), 'oldprice')]","//span[contains(concat(' ', @class, ' '), 'price')]"],@goods.id,['р.'])
        #@price=Price.where(:product_id => @goods.id).first_or_create
        #@price.cost= html.xpath("//span[contains(concat(' ', @class, ' '), 'price')]").collect {|node| node.text.gsub('р.', '').to_f}.first
        #@price.save
        #price2=html.xpath("//span[contains(concat(' ', @class, ' '), 'price')]")
        #unless price2.nil?
          #Price.create(:product_id=>@goods.id,:cost=>price2.first.text.strip.sub('р.', '').to_f)
        #end
        #@goods.prices.where(@price).first_or_create
        size=pp2.parser.xpath("//tr[contains(concat(' ', @class, ' '), 'fg')]/td")
        @goods.description=get_node_texts_s(pp2.parser,"//table[contains(concat(' ', @class, ' '), 'prps')]/tr","\n").gsub(/\s+/,' ')
        images=get_photos(pp2.parser,"//div[contains(concat(' ', @class, ' '), 'photo fl')]/a","//div[contains(concat(' ', @class, ' '), 'gallery')]/a/img")

        images.map{ |x|
          if x.length>0
            url=x.sub('thumb_', '')
            Photo.where(:product_id => @goods.id, :url => url).first_or_create
          end
        }
        @goods.category_path=catalog_title
        @goods.save
      }
      }
    }
    }
  end

  private
  # @param [Nokogiri] html
# @param [Array] xpaths
# @param [int] product_id
  # @param [Array] replace
  def add_prices(html,xpaths,product_id,replace=[])
    @price=Price.where(:product_id => product_id)
    xpaths.map{|xpath|
      cost=html.xpath(xpath).collect {|node|
        unless node.nil? && node.text.length<0
          n=node.text
          replace.map{|x| n.gsub(x, '')}
          @new=@price.where(:cost=>n.to_f).first_or_create
          @new.save
        end
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
  # @param [string] xpath_item
  # @param [string] xpath_pages
  # @param [string] host
  # @param [string] text_page
  # @return [Array]
  def get_links_pages_all(html,xpath_item,xpath_pages,host,text_page='page=')
    links=[]
    html.xpath(xpath_item).map{
        |c| link=c.attr('href')
      unless link.include? host
        link=host+link
      end
      links << link
    }
    pages=html.xpath(xpath_pages)
    if !pages.nil? && pages.size>0 && pages.size+1<pages[-1].text.to_i
      l2=pages[-1]['href']

      if l2.index(text_page).nil?
        return links
      end

      countPage=l2[l2.index(text_page)+text_page.size,3].gsub(/[^\d]/, '').to_i
      for i in 2..countPage
        l=l2.gsub(text_page+countPage.to_s,text_page+i.to_s)
        l=@shop.host+l unless l.include? @shop.host
        mechan=Mechanize.new
        mechan.get(l){|x|
          x.parser.xpath(xpath_item).map{
              |c| link=c.attr('href')
            unless link.include? host
              link=host+link
            end
            links << link
          }
        }
      end
    else
      pages.map{ |link|
        if link.to_s.include? 'href'
          l=link['href']
          l=@shop.host+l unless l.include? @shop.host
          mechan=Mechanize.new
          mechan.get(l){|x|
            x.parser.xpath(xpath_item).map{
                |c| link=c.attr('href')
            unless link.include? host
              link=host+link
            end
            links << link
            }
          }
        end
      }
    end
    return links.compact.uniq
  end

  private
  # @param [Nokogiri] html
  # @param [string] xpath_a
  # @param [string] xpath_img
  # @param [string] host_a
  # @param [string] host_img
  # @param [string] attr_a
  # @param [string] attr_img
  # @return [Array]
  def get_photos(html,xpath_a,xpath_img,host_a='',host_img='',attr_a='href',attr_img='src')
    res=[]
    if xpath_a.length>0
      html.xpath(xpath_a).collect{|node|
        if node.nil? || node[attr_a].nil?
          nil
        elsif !(node[attr_a].include? host_a)
          res << host_a+node[attr_a]
        else
          res << node[attr_a]
        end
      }
    end
    if xpath_img.length>0
      html.xpath(xpath_img).collect{|node|
        if node.nil? || node[attr_img].nil?
          nil
        elsif !(node[attr_img].include? host_img)
          res << host_img+node[attr_img]
        else
          res << node[attr_img]
        end
      }
    end

    return res.compact.uniq
  end

  private
  # @param [Nokogiri] html
  # @return [string]
  def get_node_text(html,xpath)
    return html.xpath(xpath).collect {|node| node.text.strip unless node.text.nil? }.first
  end

  private
  # @param [Nokogiri] html
  # @param [string] xpath
  # @param [string] split
  # @return [string]
  def get_node_texts_s(html,xpath,split="\n")
    res=html.xpath(xpath)
    if res.nil?
      return
    end
    return res.collect {|node| node.text.strip unless node.text.nil? }.join(split).strip
  end
end