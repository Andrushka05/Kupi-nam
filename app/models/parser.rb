require 'rubygems'
require 'open-uri'
require 'nokogiri'
require 'mechanize'
require 'action_view'

class Parser
  include ActionView::Helpers::SanitizeHelper

  def get_catalogs (id)
    @shop=Shop.find(id)
    mechan = Mechanize.new { |agent|
      # Flickr refreshes after login
      agent.follow_meta_refresh = true
      #agent.page.encoding='WINDOWS-1251'
    }
    mechan.get(@shop.url) { |p|
      p.parser.xpath(@shop.xpath).each {
          |c| link=c.attr('href')
        unless link.include? @shop.host
          link=@shop.host+link
        end
        @shop.catalog_shops.where(title: c.text, url: link).first_or_create
      }
    }
  end

  def get_rekantino (catalogs)
    @shop=Shop.find(catalogs[0].shop_id)
    catalogs.map { |catalog|
      beginTime=Time.now
      page = Nokogiri::HTML(open(catalog.url))

      #link to goods
      links=[]
      #find goods of catalog
      page.xpath("//a[contains(concat(' ', @class, ' '), 'good_list_item_img')]").each {
          |c| link=c.attr('href')
        unless link.include? @shop.host
          link=@shop.host+link
        end
        links << link
      }
      #get full info goods
      links.each { |link|
        html=Nokogiri::HTML(open(link))
        @goods=@shop.products.where(url: link).first_or_create
        if @goods.catalog_shop_id.nil?
          @goods.catalog_shop_id=catalog.id
        end
        #@pr.nil? ? @goods=@shop.products.new : @goods=@pr

        @goods.title=html.xpath("//div[contains(concat(' ', @class, ' '), 'product_description_title')]").collect { |node| node.text.strip }.first
        @goods.article=html.xpath("//span[contains(concat(' ', @class, ' '), 'article')]").collect { |node| node.text.strip }.first
        #price
        @price=Price.where(:product_id => @goods.id).first_or_create
        @price.cost= html.xpath("//div[contains(concat(' ', @class, ' '), 'product_description_row')]").select { |x| x.text.include? "руб" }.collect { |node| node.text.strip.gsub(/[^\d]/, '').to_f }.first
        @price.save
        #@goods.prices.where(@price).first_or_create
        desc=html.xpath("//div[contains(concat(' ', @class, ' '), 'product_description_row')]/p").collect { |node| node.text.strip }
        @goods.description=desc.select { |x| !x.nil? && x.length>0 }.join("\n")
        cat=html.xpath("//div[contains(concat(' ', @class, ' '), 'bread_crumb_big')]/a").collect { |node|
          unless node.text.include? 'Каталог'
            node.text.strip
          end }
        @goods.category_path=cat.select { |x| x!=nil }.join('/')
        size=html.xpath("//select[contains(concat(' ', @id, ' '), 'size')]/option").collect { |node|
          unless node.text.include? 'размер'
            node.text.strip
          end }
        @goods.size=size.select { |x| x!=nil }.join('; ')
        images=html.xpath("//a[contains(concat(' ', @class, ' '), 'cloud-zoom')]").collect { |node|
          if node.nil? || node.attr('href').nil?
            nil
          elsif !(node.attr('href').include? @shop.host)
            @shop.host+node.attr('href')
          else
            node.attr('href')
          end }
        images.select { |x| x!=nil }.each { |x| Photo.where(:product_id => @goods.id, :url => x).first_or_create }

        @goods.color=''
        @goods.save
      }
      endTime=Time.now-beginTime
      @c=CatalogShop.where(:id => catalog.id).first
      @c.time_download=Time.new(endTime.to_i)
      @c.date_last_download=DateTime.now
      @c.save
    }
  end

  def get_lala_style(catalogs)
    @shop=Shop.find(catalogs[0].shop_id)
    catalogs.map { |catalog|
      beginTime=Time.now
      mechan = Mechanize.new { |agent|
        # Flickr refreshes after login
        agent.follow_meta_refresh = true
      }
      encoding = 'WINDOWS-1251' # 'UTF-8'
      mechan.get(catalog.url) { |page|
        page.encoding = 'windows-1251'
        catalog_title=catalog.title
        #link to goods
        links=get_links_pages_all(page.parser, "//a[contains(concat(' ', @class, ' '), 'prod_more')]", "//div[contains(concat(' ', @class, ' '), 'shop2-pageist')]/a", @shop.host, '/p/')
        #pages
        page.parser.xpath("//div[contains(concat(' ', @class, ' '), 'shop2-pageist')]/a").map { |link|
          if link.to_s.include? 'href'
            l=link['href']
            l=@shop.host+l unless l.include? @shop.host
            html=Nokogiri::HTML(mechan.get(l).body)
            get_links(html, "//a[contains(concat(' ', @class, ' '), 'prod_more')]", @shop.host).map { |x|
              links << x
            }
          end
        }
        links=links.compact.uniq
        #get full info goods
        links.each { |link|
          mechan.get(link) { |html|
            html.encoding = 'windows-1251'
            @goods=@shop.products.where(url: link).first_or_create
            if @goods.catalog_shop_id.nil?
              @goods.catalog_shop_id=catalog.id
            end

            @goods.title=get_node_text(html.parser, "//div[contains(concat(' ', @class, ' '), 'product-right-bar')]/h1")
            code=get_node_text(html.parser, "//div[contains(concat(' ', @class, ' '), 'product-code')]/span")
            @goods.article=code.strip
            code=get_node_text(html.parser, "//div[contains(concat(' ', @class, ' '), 'product-code')]")
            @goods.color=code.slice(code.rindex("цвет:")+5, code.length-code.rindex("цвет:")-5).strip if code.include? "цвет:"
            #price
            @price=Price.where(:product_id => @goods.id).first_or_create
            @price.cost= html.parser.xpath("//div[contains(concat(' ', @class, ' '), 'product-accessory-prise')][1]").select { |x| x.text.include? "руб" }.collect { |node| node.text.gsub(/[^\d]/, '').to_f }.first
            @price.save
            #@goods.prices.where(@price).first_or_create
            desc=html.parser.xpath("//div[contains(concat(' ', @id, ' '), 'tabs-1')]/p").collect { |node| node.text.strip }.join("\n")

            @goods.category_path=catalog_title
            if !desc.index("Размерный ряд модели").nil? && !desc.index("Цвет").nil?
              size=desc[desc.index("Размерный ряд модели")+21, desc.index("Цвет")-desc.index("Размерный ряд модели")-21]
              desc=desc[0, desc.index("Размерный ряд модели")]
              unless size.nil?
                if size.length>250
                  size=size[0, size.downcase.index(@goods.color.downcase)]
                end
                @goods.size=size.gsub(",", "; ").gsub(".", "").strip
              end
            elsif !desc.index("Размерный ряд модели").nil?
              size=desc[desc.index("Размерный ряд модели")+21, desc.length-desc.index("Размерный ряд модели")-21]
              desc=desc[0, desc.index("Размерный ряд модели")]
              unless size.nil?
                if size.length>250
                  ytr=@goods.color.upcase
                  ss=size.upcase
                  z=ss.index(ytr)
                  size=size[0, z]
                end
                @goods.size=size.gsub(",", "; ").gsub(".", "").strip
              end
            end
            @goods.description=desc
            images=get_photos(html.parser, "//li/a[contains(concat(' ', @class, ' '), 'highslide')]", "", @shop.host) #.collect{|node| if node.nil? || node.attr('href').nil?
            #nil
            #elsif !(node.attr('href').include? @shop.host)
            # @shop.host+node.attr('href')
            #else
            # node.attr('href')
            #end }
            html.parser.xpath("//div[contains(concat(' ', @class, ' '), 'product-thumbnails-wrap')]/ul/li/img").collect { |node|
              str=node.attr('onclick')
              str=str[str.index("this,")+5, str.index(",", str.index("this,")+5)-str.index("this,")-5].gsub!("'", "").strip!
              if !str.include? @shop.host
                images << @shop.host+str
              else
                images << str
              end
            }

            images.uniq!
            images.map { |x|
              Photo.where(:product_id => @goods.id, :url => x).first_or_create if x.length>0
            }
            @goods.save

            links2=html.parser.xpath("//div[contains(concat(' ', @class, ' '), 'product-accessory-name')]/a").map { |x|
              unless x.attr('href').equal? link
                unless x.attr('href').include? @shop.host
                  @shop.host+x.attr('href')
                else
                  x.attr('href')
                end
              end
            }
            links2.map { |l|
              mechan.get(l) { |html2|
                @goods2=@shop.products.where(url: l).first_or_create
                if @goods2.catalog_shop_id.nil?
                  @goods2.catalog_shop_id=@goods.catalog_shop_id
                end

                @goods2.title=get_node_text(html2.parser, "//div[contains(concat(' ', @class, ' '), 'product-right-bar')]/h1")
                code2=get_node_text(html2.parser, "//div[contains(concat(' ', @class, ' '), 'product-code')]/span")
                @goods2.article=code2.strip
                code2=get_node_text(html2.parser, "//div[contains(concat(' ', @class, ' '), 'product-code')]")
                @goods2.color=code2.slice(code2.index("цвет:")+5, code2.length-code2.index("цвет:")-5).strip if code2.include? "цвет:"
                #price
                @price2=Price.where(:product_id => @goods2.id).first_or_create
                @price2.cost= html2.parser.xpath("//div[contains(concat(' ', @class, ' '), 'product-accessory-prise')][1]").select { |x|
                  x.text.include? "руб" }.collect { |node| node.text.gsub(/[^\d]/, '').to_f
                }.first
                if @price2.cost.nil?
                  @price2.cost=0
                end
                @price2.save
                #@goods.prices.where(@price).first_or_create
                desc2=html2.parser.xpath("//div[contains(concat(' ', @id, ' '), 'tabs-1')]/p").collect { |node| node.text.strip }.join("\n")

                @goods2.category_path=catalog_title
                if !desc2.index("Размерный ряд модели").nil? && !desc2.index("Цвет").nil?
                  size2=desc2[desc2.index("Размерный ряд модели")+21, desc2.index("Цвет")-desc2.index("Размерный ряд модели")-21]
                  desc2=desc2[0, desc2.index("Размерный ряд модели")]
                  unless size2.nil?
                    if size2.length>250
                      size2=size2[0, size2.downcase.index(@goods2.color.downcase)]
                    end
                    @goods2.size=size2.gsub(",", "; ").gsub(".", "").strip
                  end
                elsif !desc2.index("Размерный ряд модели").nil?
                  size2=desc2[desc2.index("Размерный ряд модели")+21, desc2.length-desc2.index("Размерный ряд модели")-21]
                  desc2=desc2[0, desc2.index("Размерный ряд модели")]
                  unless size2.nil?
                    if size2.length>250
                      size2=size2[0, size2.downcase.index(@goods2.color.downcase)]
                    end
                    @goods2.size=size2.gsub(",", "; ").gsub(".", "").strip
                  end
                end
                @goods2.description=desc2
                images3=get_photos(html.parser, "//li/a[contains(concat(' ', @class, ' '), 'highslide')]", "", @shop.host) #.collect{|node| if node.nil? || node.attr('href').nil?
                #nil
                #elsif !(node.attr('href').include? @shop.host)
                #@shop.host+node.attr('href')
                #else
                #node.attr('href')
                #end }
                html2.parser.xpath("//div[contains(concat(' ', @class, ' '), 'product-thumbnails-wrap')]/ul/li/img").collect { |node|
                  str=node.attr('onclick')
                  str=str[str.index("this,")+5, str.index(",", str.index("this,")+5)-str.index("this,")-5].gsub!("'", "").strip!
                  unless str.include? @shop.host
                    images3 << @shop.host+str
                  else
                    images3 << str
                  end
                }
                images3.uniq!
                images3.map { |x| Photo.where(:product_id => @goods.id, :url => x).first_or_create if x.length>0 }
                @goods2.save
              }
            }
            sleep(0.5)
          }
        }
      }
      endTime=Time.now-beginTime
      @c=CatalogShop.where(:id => catalog.id).first
      @c.time_download=Time.new(endTime.to_i)
      @c.date_last_download=DateTime.now
      @c.save
    }
  end

  def get_arabella(catalogs)
    @shop=Shop.find(catalogs[0].shop_id)

    mechan = Mechanize.new { |agent|
      # Flickr refreshes after login
      agent.follow_meta_refresh = true

      #agent.page.encoding='WINDOWS-1251'
    }
    encoding = 'WINDOWS-1251' # 'UTF-8'

    mechan.get(@shop.url) { |p|
      log = p.form_with(:id => 'login_block__form') { |form|
        form.email='Krasnoselskova@rambler.ru'
        form.password='123456'
      }.submit
    }
    mechan.get(@shop.url)
    catalogs.map { |catalog|
      beginTime=Time.now
      mechan.get(catalog.url) { |p|

        page = Nokogiri::HTML(p.body, nil, encoding) #+"?characteristics%5B%5D=1290270&page_size=100"
        page.remove_namespaces!
        catalog_title=catalog.title

        links=get_links_pages_all(p.parser, "//p[contains(concat(' ', @class, ' '), 'title')]/a", "//span[contains(concat(' ', @class, ' '), 'pagination_page')]/a", @shop.host, "page=")
        links=links.compact.uniq
        #get full info goods
        links.each { |link|
          mechan.get(link) { |pp2|

            @goods=@shop.products.where(url: link).first_or_create
            if @goods.catalog_shop_id.nil?
              @goods.catalog_shop_id=catalog.id
            end

            @goods.title=get_node_text(pp2.parser, "//table[contains(concat(' ', @class, ' '), 'prps')]/tr[1]").gsub("Товар:", "").gsub(/\s+/, ' ').strip
            @goods.article=get_node_text(pp2.parser, "//div[contains(concat(' ', @class, ' '), 'fl prod-info')]/h1").strip
            @goods.color=""
            add_prices(pp2.parser, ["//span[contains(concat(' ', @class, ' '), 'oldprice')]", "//span[contains(concat(' ', @class, ' '), 'price')]"], @goods.id, ['р.'])
            size=get_node_texts_s(pp2.parser, "//tr[contains(concat(' ', @class, ' '), ' fg ')]/td", '; ')
            @goods.description=get_node_texts_s(pp2.parser, "//table[contains(concat(' ', @class, ' '), 'prps')]/tr", ";;").gsub("Товар:","").gsub(/\s+/, ' ').gsub("\n","").gsub(";;","\n")
            images=get_photos(pp2.parser, "//div[contains(concat(' ', @class, ' '), 'photo fl')]/a", "//div[contains(concat(' ', @class, ' '), 'gallery')]/a/img")

            @goods.size=size
            images.map { |x|
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
      endTime=Time.now-beginTime
      @c=CatalogShop.where(:id => catalog.id).first
      @c.time_download=Time.new(endTime.to_i)
      @c.date_last_download=DateTime.now
      @c.save
    }
  end

  def get_mix_mode(catalogs)
    @shop=Shop.find(catalogs[0].shop_id)
    mechan = Mechanize.new { |agent|
      # Flickr refreshes after login
      agent.follow_meta_refresh = true

      #agent.page.encoding='WINDOWS-1251'
    }
    encoding = 'WINDOWS-1251' # 'UTF-8'

    catalogs.map { |catalog|
      beginTime=Time.now
      mechan.get(catalog.url+"?limitstart=0&limit=65535") { |p|
        page = Nokogiri::HTML(p.body, nil, encoding) #+"?characteristics%5B%5D=1290270&page_size=100"
        page.remove_namespaces!
        catalog_title=catalog.title
        #link to goods
        links=get_links(p.parser, "//a[contains(concat(' ', @class, ' '), 'relative diblock')]", @shop.host)
        links=links.compact.uniq
        #get full info goods
        links.each { |link|
          mechan.get(link) { |pp2|

            @gs=@shop.products.where(url: link)
            if @gs.size==0
              @goods=@shop.products.create
            else
              @goods=@gs.first
            end
            if @goods.catalog_shop_id.nil?
              @goods.catalog_shop_id=catalog.id
            end

            @goods.title=get_node_text(pp2.parser, "//h1[contains(concat(' ', @class, ' '), 'item_name')]").gsub("Товар:", "").strip.mb_chars.capitalize
            desc=[]
            pp2.parser.xpath("//div[contains(concat(' ', @class, ' '), 'content')]").map { |x|
              temp=x.to_s.split("<br>")
              temp.map { |t|
                res=strip_tags(t)
                if res.include? "Артикул"
                  @goods.article=res[res.index(":")+1, res.length-res.index(":")-1].strip
                elsif res.include? "Цвет"
                  @goods.color=res[res.index(":")+1, res.length-res.index(":")-1].strip
                else
                  desc << res.to_s.gsub(/\s+/, ' ')
                end
              }
            }
            @goods.description=get_node_texts_s(pp2.parser, "//td[contains(concat(' ', @id, ' '), 'right_content')]/p", "\n")
            if desc.length>0
              if @goods.description.length>0
                @goods.description=desc.join("\n")+"\n"+@goods.description
              else
                @goods.description=desc
              end
            end
            images=get_photos(pp2.parser, "", "//img[contains(concat(' ', @id, ' '), 'image_m')]")
            images.map { |x|
              if x.length>0
                url=x.sub("/z_", "/")
                Photo.where(:product_id => @goods.id, :url => url).first_or_create
              end
            }
            @goods.category_path=get_nodes_a(pp2.parser, "//div[contains(concat(' ', @id, ' '), 'breadcrumbs')]/a", ["Mix-Mode", "Оптовый интернет магазин"]).join("/").mb_chars.capitalize
            size=get_nodes_a(pp2.parser, "//table[contains(concat(' ', @id, ' '), 'sizes')]/tr[1]/td", ["Размер"])

            prices=get_nodes_a(pp2.parser, "//table[contains(concat(' ', @id, ' '), 'sizes')]/tr[2]/td", ['Оптовая'], ['руб.'], [], false)
            if prices.size>0

              prices.size.times { |i|
                id=@goods.id
                if i==0
                  @goods.size=size[i]
                  @goods.save
                else
                  @goodsNew=@gs.where(:size => size[i]).first_or_create
                  @goodsNew.article=@goods.article
                  @goodsNew.size=size[i].strip
                  id=@goodsNew.id
                  @goodsNew.save
                end
                @price=Price.where(:product_id => id)
                @new=@price.where(:cost => prices[i].to_f).first_or_create
                @new.save
              }
            else
              pric=pp2.parser.xpath("//div[contains(concat(' ', @class, ' '), 'price')]").collect { |x| x.text unless x.nil? }.first
              @price=Price.where(:product_id => @goods.id)
              @new=@price.where(:cost => pric.gsub('руб.', '').to_f).first_or_create
              @new.save
              @goods.size=size.join("; ").strip
              @goods.state="no_sale"
              @goods.save
            end
          }
        }
      }
      endTime=Time.now-beginTime
      @c=CatalogShop.where(:id => catalog.id).first
      @c.time_download=Time.new(endTime.to_i)
      @c.date_last_download=DateTime.now
      @c.save
    }
  end

  def get_yulia_prom(catalogs)
    @shop=Shop.find(catalogs[0].shop_id)
    mechan = Mechanize.new { |agent|
      # Flickr refreshes after login
      agent.follow_meta_refresh = true

      #agent.page.encoding='WINDOWS-1251'
    }
    encoding = 'WINDOWS-1251' # 'UTF-8'

    mechan.get(@shop.url)
    catalogs.map { |catalog|
      beginTime=Time.now
      begin
      mechan.get(catalog.url+"?product_items_per_page=48") { |p|

        catalog_title=catalog.title

        links=get_links_pages_all(p.parser, "//a[contains(concat(' ', @id, ' '), 'link_to_product')]", "//a[contains(concat(' ', @class, ' '), 'b-pager__link')][last()-1]", @shop.host, "page_")
        links=links.compact.uniq
        #get full info goods
        links.each { |link|
          begin
          mechan.get(link) { |pp2|

            @goods=@shop.products.where(url: link).first_or_create
            if @goods.catalog_shop_id.nil?
              @goods.catalog_shop_id=catalog.id
            end

            @goods.title=get_node_text(pp2.parser, "//h1[contains(concat(' ', @class, ' '), 'b-product__name')]").strip
            article=get_node_text(pp2.parser, "//span[contains(concat(' ', @class, ' '), 'b-product__sku')]")
            article.gsub("Код:", "").strip unless article.nil?
            article=@goods.title if article.nil?
            @goods.article=article
            @goods.color=""
            add_prices(pp2.parser, ["//p[contains(concat(' ', @class, ' '), 'b-product__price')]", "//li[contains(concat(' ', @class, ' '), 'b-product__additional-price')]/div[contains(concat(' ', @class, ' '), 'b-data-list__name')]/span"], @goods.id, ['грн.'])

            @goods.description=get_node_texts_s(pp2.parser, "//div[contains(concat(' ', @class, ' '), 'b-content__body b-user-content')]", "\n").gsub(/\s+/, ' ')
            images=get_photos(pp2.parser, "//a[contains(concat(' ', @rel, ' '), 'imagebox')]", "//img[contains(concat(' ', @class, ' '), 'b-centered-image__img')]")

            @goods.size=""
            images.map { |x|
              if x.length>0
                Photo.where(:product_id => @goods.id, :url => x).first_or_create
              end
            }
            @goods.category_path=get_node_texts_s(pp2.parser, "//a[contains(concat(' ', @class, ' '), 'b-breadcrumb__link ')]", "/",['Prom.ua', 'Одесса','Интернет-магазин "YULIA"', 'Ассортимент моделей'])
            @goods.save
            #sleep(1.5)
          }
          rescue Timeout::Error
            puts "Timeout!"
          rescue Net::HTTPNotFound
            puts '404!'
          end
        }

      }
      rescue Net::HTTPNotFound
        puts '404!'
      end
      endTime=Time.now-beginTime
      @c=CatalogShop.where(:id => catalog.id).first
      @c.time_download=Time.new(endTime.to_i)
      @c.date_last_download=DateTime.now
      @c.save
    }
  end

  def get_rawjeans(catalogs)
    @shop=Shop.find(catalogs[0].shop_id)
    mechan = Mechanize.new { |agent|
      # Flickr refreshes after login
      agent.follow_meta_refresh = true

      #agent.page.encoding='WINDOWS-1251'
    }
    encoding = 'WINDOWS-1251' # 'UTF-8'

    mechan.get(@shop.url)
    catalogs.map { |catalog|
      beginTime=Time.now
      mechan.get(catalog.url+"?product_items_per_page=48") { |p|

        page = Nokogiri::HTML(p.body, nil, encoding) #+"?characteristics%5B%5D=1290270&page_size=100"
        page.remove_namespaces!
        links=get_links_pages_all(p.parser, "//a[contains(concat(' ', @class, ' '), 'good_title')]", "//div[contains(concat(' ', @class, ' '), 'pages')]/a[last()-1]", @shop.host, 'start=')
        links=links.compact.uniq
        #get full info goods
        links.each { |link|
          mechan.get(link) { |pp2|

            @goods=@shop.products.where(url: link).first_or_create
            if @goods.catalog_shop_id.nil?
              @goods.catalog_shop_id=catalog.id
            end

            @goods.title=get_node_text(pp2.parser, "//span[contains(concat(' ', @class, ' '), 'good_title')]").strip
            @goods.article=@goods.title

            desc=pp2.parser.xpath("//span[contains(concat(' ', @class, ' '), 'good_option')]").map { |x| x.to_s }.join("\n")
            if desc.split("<div>").size>desc.split("<p>").size
              desc=desc.split("<div>")
            else
              if desc.split("<br>").size>desc.split("<p>").size
                desc=desc.split("<br>")
              else
                desc=desc.split("<p>")
              end
            end
            if desc.size==1
              trw=''
            end
            rd=[]
            size=''
            color=''
            desc.map { |x|
              r=strip_tags(x).strip
              if r.include? 'Размер'
                if r.include? 'Цвет'
                  size << strip_tags(r[r.index(':', r.index("Размер"))+1, r.index('Цвет')-r.index(':', r.index("Размер"))-1])
                  color << strip_tags(r[r.index(':', r.index("Цвет"))+1, r.length-r.index(':', r.index("Цвет"))-1])
                else
                  size << strip_tags(r[r.index(':', r.index("Размер"))+1, r.length-r.index(':', r.index("Размер"))-1])
                end
              elsif r.include? 'Цвет'
                color << strip_tags(r[r.index(':', r.index("Цвет"))+1, r.length-r.index(':', r.index("Цвет"))-1])
              elsif r.length>0
                rd << r
              end
            }
            unless size.index('(').nil?
              size=size[0, size.index('(')].strip
            end
            unless color.index('(').nil?
              color=color[0, color.index('(')].strip
            end
            unless color.index('Состав').nil?
              rd << color[color.index('Состав'), color.length-color.index('Состав')]
              color=color[0, color.index('Состав')].strip
            end
            size=size.gsub(' ', '; ') if size.length>0

            @goods.description=rd.join("\n")
            images=get_photos(pp2.parser, "", "//a[contains(concat(' ', @class, ' '), 'list_images')]/img", "", @shop.host)
            @goods.color=color
            @goods.size=size
            images.map { |x|
              if x.length>0
                Photo.where(:product_id => @goods.id, :url => x).first_or_create
              end
            }
            @goods.category_path='Новинки'
            @goods.save

          }
        }
      }
      endTime=Time.now-beginTime
      @c=CatalogShop.where(:id => catalog.id).first
      @c.time_download=Time.new(endTime.to_i)
      @c.date_last_download=DateTime.now
      @c.save
    }
  end

  def get_noch_sorochki(catalogs)
    @shop=Shop.find(catalogs[0].shop_id)
    mechan = Mechanize.new { |agent|
      # Flickr refreshes after login
      agent.follow_meta_refresh = true
      #agent.page.encoding='WINDOWS-1251'
    }
    encoding = 'WINDOWS-1251' # 'UTF-8'
    mechan.get(@shop.url)
    catalogs.map { |catalog|
      beginTime=Time.now
      mechan.get(catalog.url) { |p|
        page = Nokogiri::HTML(p.body, nil, encoding) #+"?characteristics%5B%5D=1290270&page_size=100"
        page.remove_namespaces!
        catalog_title=catalog.title
        links=get_links_pages_all(p.parser, "//a[text()='подробнее...']", "//div/a[contains(concat(' ', @href, ' '), 'katalog')][last()]", @shop.host, "katalog")
        links=links.compact.uniq
        #get full info goods
        links.each { |link|
          mechan.get(link) { |pp2|
            @goods=@shop.products.where(url: link).first_or_create
            if @goods.catalog_shop_id.nil?
              @goods.catalog_shop_id=catalog.id
            end

            @goods.title=get_node_text(pp2.parser, "//tr/td[3]/h3")
            @goods.article=get_node_text(pp2.parser, "//tr/td[3]/p[1]").gsub("Артикульный №", "")
            @goods.color=get_node_texts_s(pp2.parser, "//table[contains(concat(' ', @cellpadding, ' '), '1')]/tr/td[1]", '; ', ['цвет'])
            add_prices(pp2.parser, ["//form/table/tr/td[3]"], @goods.id, ['Цена', 'рублей'])
            size=get_node_texts_s(pp2.parser, "//tr/td/ul/li", '; ', ['размер'])
            @goods.description=get_node_texts_s(pp2.parser, "//tr/td/p", "\n").gsub(/\s+/, ' ')
            images=get_photos(pp2.parser, '', "//td/div/img | //tr/td/img")

            @goods.size=size
            images.map { |x|
              if x.length>0
                Photo.where(:product_id => @goods.id, :url => x).first_or_create
              end
            }
            @goods.category_path=catalog_title
            @goods.save
          }
        }
      }
      endTime=Time.now-beginTime
      @c=CatalogShop.where(:id => catalog.id).first
      @c.time_download=Time.new(endTime.to_i)
      @c.date_last_download=DateTime.now
      @c.save
    }
  end

  def get_deniliz(catalogs)
    @shop=Shop.find(catalogs[0].shop_id)
    mechan = Mechanize.new { |agent|
      # Flickr refreshes after login
      agent.follow_meta_refresh = true
      #agent.page.encoding='WINDOWS-1251'
    }
    encoding = 'WINDOWS-1251' # 'UTF-8'
    mechan.get(@shop.url) { |p|
      log = p.form_with() { |form|
        form.email='yunnesa@mail.ru'
        form.password='yunnesa2405'
      }.submit
    }
    mechan.get(@shop.url)
    catalogs.map { |catalog|
      beginTime=Time.now
      begin
      mechan.get(catalog.url+"?page=all") { |p|
        page = Nokogiri::HTML(p.body, nil, encoding) #+"?characteristics%5B%5D=1290270&page_size=100"
        page.remove_namespaces!
        catalog_title=catalog.title
        links=get_links(p.parser, "//h4[contains(concat(' ', @itemprop, ' '), 'name')]/a", @shop.host)
        links=links.compact.uniq
        #get full info goods
        links.each { |link|
          mechan.get(link) { |pp2|
            @goods=@shop.products.where(url: link).first_or_create
            if @goods.catalog_shop_id.nil?
              @goods.catalog_shop_id=catalog.id
            end

            @goods.title=get_node_text(pp2.parser, "//div[contains(concat(' ', @class, ' '), 'title')]/h1")
            @goods.article=get_node_text(pp2.parser, "//span[contains(concat(' ', @itemprop, ' '), 'identifier')]")
            @goods.color=''
            color=''
            add_prices(pp2.parser, ["//span[contains(concat(' ', @id, ' '), 'price')]"], @goods.id, [])
            size=''
            desc=''
            get_nodes_a(pp2.parser, "//ul[contains(concat(' ', @class, ' '), 'features')]/li", []).map { |x|
              temp=x.text.strip
              if temp.include? 'Размер'
                size = strip_tags(temp[temp.index(":", temp.index("Размер"))+1, temp.length-temp.index(":", temp.index("Размер"))-1])
              elsif temp.include? 'Цвет'
                color= strip_tags(temp[temp.index(":", temp.index("Цвет"))+1, temp.length-temp.index(":", temp.index("Цвет"))-1])
              elsif temp.length>0
                desc << temp
              end
            }
            @goods.description=get_node_texts_s(pp2.parser, "//div[contains(concat(' ', @class, ' '), 'block description')]/p", "\n").gsub(/\s+/, ' ')
            images=get_photos(pp2.parser, "//a[contains(concat(' ', @class, ' '), 'cloud-zoom-gallery')]", "//img[contains(concat(' ', @class, ' '), 'b-centered-image__img')]")
            if @goods.description.length>0
              @goods.description << "\n"+desc.join("\n")
            else
              @goods.description=desc.join("\n")
            end
            @goods.size=size
            images.map { |x|
              if x.length>0
                Photo.where(:product_id => @goods.id, :url => x).first_or_create
              end
            }
            @goods.category_path=get_node_texts_s(pp2.parser, "//div[contains(concat(' ', @class, ' '), 'breadcrumbs')]/a", "/", ["Главная"])
            @goods.save
          }
        }
      }
      rescue Net::HTTPNotFound
       puts '404!'
      end
      endTime=Time.now-beginTime
      @c=CatalogShop.where(:id => catalog.id).first
      @c.time_download=Time.new(endTime.to_i)
      @c.date_last_download=DateTime.now
      @c.save
    }
  end

  private
  # @param [Nokogiri] html
  # @param [Array] xpaths
  # @param [int] product_id
  # @param [Array] replace
  def add_prices(html, xpaths, product_id, replace=[])
    @price=Price.where(:product_id => product_id)
    no_price=true
    xpaths.map { |xpath|
      cost=html.xpath(xpath).collect { |node|
        unless node.nil? && node.text.length<0
          n=node.text
          replace.map { |x| n.gsub(x, '') }
          @new=@price.where(:cost => n.to_f).first_or_create
          @new.save
        end
        no_price=false
      }
    }
    return no_price
  end

  private
  # @param [Nokogiri] html
  # @param [string] xpath
  # @param [string] host
  def get_links(html, xpath, host)
    links=[]
    html.xpath(xpath).map {
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
  def get_links_pages_all(html, xpath_item, xpath_pages, host, text_page='page=')
    links=[]
    html.xpath(xpath_item).map {
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

      countPage=l2[l2.index(text_page)+text_page.size, 3].gsub(/[^\d]/, '').to_i
      for i in 2..countPage
        l=l2.gsub(text_page+countPage.to_s, text_page+i.to_s)
        l=@shop.host+l unless l.include? @shop.host
        mechan=Mechanize.new
        mechan.get(l) { |x|
          x.parser.xpath(xpath_item).map {
              |c| link=c.attr('href')
            unless link.include? host
              link=host+link
            end
            links << link
          }
        }
      end
    else
      pages.map { |link|
        if link.to_s.include? 'href'
          l=link['href']
          l=@shop.host+l unless l.include? @shop.host
          mechan=Mechanize.new
          mechan.get(l) { |x|
            x.parser.xpath(xpath_item).map {
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
  def get_photos(html, xpath_a, xpath_img, host_a='', host_img='', attr_a='href', attr_img='src')
    res=[]
    if xpath_a.length>0
      html.xpath(xpath_a).collect { |node|
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
      html.xpath(xpath_img).collect { |node|
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
  def get_node_text(html, xpath)
    return html.xpath(xpath).collect { |node| node.text.strip unless node.text.nil? }.first
  end

  private
  # @param [Nokogiri] html
  # @param [string] xpath
  # @param [string] split
  # @return [string]
  # @param [Array] not_word
  def get_node_texts_s(html, xpath, split="\n", not_word=[])
    res=[]
    html.xpath(xpath).map { |x|
      unless x.text.nil?
        temp=x.text.strip.gsub(/\s+/, ' ')
        save=false
        not_word.map { |z| save=true if temp.include? z }
        res << temp unless save
      end
    }
    return res.join(split)
  end

  private
  # @param [Nokogiri] html
  # @param [string] xpath
  # @param [Array] not_word
  # @param [Array] word
  # @param [Array] replace
  # @return [Array]
  def get_nodes_a(html, xpath, not_word, replace=[], word=[], uniq=true)
    res=[]
    html.xpath(xpath).map { |x|
      t=x.text.gsub(/\s+/, ' ').strip
      temp=false
      not_word.map { |z|
        temp=true if t.include? z
      }
      if temp
        t=nil
      else
        if word.size>0
          if word.include? t
            replace.map { |a| t.sub(a, '') }
          else
            t=nil
          end
        else
          replace.map { |a| t.sub(a, '') }
        end
      end
      res << t.to_s.strip unless t.nil?
    }
    if uniq then
      return res.compact.uniq
    else
      return res.compact
    end
  end

  private
  def get_attrs_a(html, xpath, attr, replace=[], word=[])
    res=[]
    html.xpath(xpath).map { |x|
      t=x[attr]
      if word.size>0
        (word.include? t) ? replace.map { |r| t.sub(r, "") } : t=nil
      else
        replace.map { |r| t.sub(r, "") }
      end
      res << t.to_s.strip unless t.nil?
    }
    return res.compact.uniq
  end


end