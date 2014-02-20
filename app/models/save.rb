require 'rubygems'
require 'writeexcel/biffwriter'
require 'writeexcel/olewriter'
require 'writeexcel/formula'
require 'writeexcel/format'
require 'writeexcel/worksheet'
require "writeexcel/workbook"
require 'writeexcel/chart'
require 'writeexcel/charts/area'
require 'writeexcel/charts/bar'
require 'writeexcel/charts/column'
require 'writeexcel/charts/external'
require 'writeexcel/charts/line'
require 'writeexcel/charts/pie'
require 'writeexcel/charts/scatter'
require 'writeexcel/charts/stock'
require 'writeexcel/storage_lite'
require 'writeexcel/compatibility'
require 'writeexcel/debug_info'

class Save
  def xls(shop_id)
    @shop=Shop.find(shop_id)
    workbook = WriteExcel.new(@shop.title+".xls")
    worksheet  = workbook.add_worksheet
    #max count prices
    count_price=0
    count_photo=0
    count_ext_prop=0
    @shop.products.each { |x| count_price=x.prices.size if !x.prices.nil? && x.prices.size > count_price
      #count_ext_prop=x.ext_props.size if ExtProp.find_all_by_product_id.size>0 && x.ext_props.size > count_ext_prop
      count_photo=x.photos.size if !x.photos.nil? && x.photos.size > count_photo
    }

    count_column=0
    worksheet.write(0,count_column,'main_category')
    worksheet.write(1,count_column,'Рубрика в общем каталоге')
    count_column+=1
    worksheet.write(0,count_column,'category_path')
    worksheet.write(1,count_column,'Рубрика в каталоге закупки')
    count_column+=1
    worksheet.write(0,count_column,'title')
    worksheet.write(1,count_column,'Название')
    count_column+=1
    worksheet.write(0,count_column,'article2')
    worksheet.write(1,count_column,'Артикул')
    count_column+=1
    worksheet.write(0,count_column,'article')
    worksheet.write(1,count_column,'Артикул поставщика (необязательно)')
    count_column+=1
    count_price.times{|i|
      worksheet.write(0,count_column,'prices'+i.to_s)
      worksheet.write(1,count_column,'Оптовая цена '+i.to_s)
      count_column+=1
    }
    worksheet.write(0,count_column,'client_price')
    worksheet.write(1,count_column,'Цена c орг. сбором')
    count_column+=1
    worksheet.write(0,count_column,'size')
    worksheet.write(1,count_column,'Размер')
    count_column+=1
    worksheet.write(0,count_column,'color')
    worksheet.write(1,count_column,'Цвет')
    #ext prop
    if count_ext_prop>0
      count_ext_prop.times{|i|
        worksheet.write(0,count_column,'props'+i)
        worksheet.write(1,count_column,'Свойство'+i)
        count_column+=1
      }
    end
    count_column+=1
    worksheet.write(0,count_column,'description')
    worksheet.write(1,count_column,'Описание')
    count_column+=1
    worksheet.write(0,count_column,'url')
    worksheet.write(1,count_column,'Ссылка на сайте поставщика')
    count_column+=1
    #photos
    count_photo.times{|i|
      worksheet.write(0,count_column,'photos'+i.to_s)
      worksheet.write(1,count_column,'Фото '+i.to_s)
      count_column+=1
    }

    count_row=2
    @shop.products.each { |p|
      count_column=0
      worksheet.write(count_row,count_column,p.main_categories)
      count_column+=1
      worksheet.write(count_row,count_column,p.category_path)
      count_column+=1
      worksheet.write(count_row,count_column,p.title)
      count_column+=1
      worksheet.write(count_row,count_column,p.article2)
      count_column+=1
      worksheet.write(count_row,count_column,p.article)
      count_column+=1
      if count_price>0
        p.prices.map{|price|
        worksheet.write(count_row,count_column,price.cost)
        count_column+=1
      }
      end
      worksheet.write(count_row,count_column,p.client_prices)
      count_column+=1
      worksheet.write(count_row,count_column,p.size)
      count_column+=1
      worksheet.write(count_row,count_column,p.color)
      #ext prop
      if count_ext_prop>0
        p.ext_props.map{|ext|
          worksheet.write(count_row,count_column,ext.value)
          count_column+=1
        }
      end
      count_column+=1
      worksheet.write(count_row,count_column,p.description)
      count_column+=1
      worksheet.write(count_row,count_column,p.url)
      count_column+=1
      #photos
      if count_photo>0
        p.photos.map{|photo|
          worksheet.write(count_row,count_column,photo.url)
          count_column+=1
        }
      end
      count_row+=1
    }

    # write to file
    workbook.close
  end

  def xlsx(shop_id)

  end
end