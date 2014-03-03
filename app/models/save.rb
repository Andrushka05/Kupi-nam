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
    # Add and define a format
    format = workbook.add_format(:bold=>1,:border=>1,:align=>'center')
    format2=workbook.add_format(:border=>1)
    #format.set_bold
    #format.set_border()
    #format.set_color('red')
    #format.set_align('center')
    count_column=0
    worksheet.write(0,count_column,'main_category',format2)
    worksheet.write(1,count_column,'Рубрика в общем каталоге',format)
    count_column+=1
    worksheet.write(0,count_column,'category_path',format2)
    worksheet.write(1,count_column,'Рубрика в каталоге закупки',format)
    count_column+=1
    worksheet.write(0,count_column,'title',format2)
    worksheet.write(1,count_column,'Название',format)
    count_column+=1
    worksheet.write(0,count_column,'article',format2)
    worksheet.write(1,count_column,'Артикул',format)
    count_column+=1
    count_price.times{|i|
      worksheet.write(0,count_column,'prices'+i.to_s,format2)
      worksheet.write(1,count_column,'Оптовая цена '+i.to_s,format)
      count_column+=1
    }
    worksheet.write(0,count_column,'size',format2)
    worksheet.write(1,count_column,'Размер',format)
    count_column+=1
    worksheet.write(0,count_column,'color',format2)
    worksheet.write(1,count_column,'Цвет',format)
    count_column+=1
    #ext prop
    if count_ext_prop>0
      count_ext_prop.times{|i|
        worksheet.write(0,count_column,'option'+i,format2)
        worksheet.write(1,count_column,'Свойство'+i,format)
        count_column+=1
      }
    end
    worksheet.write(0,count_column,'description',format2)
    worksheet.write(1,count_column,'Описание',format)
    count_column+=1
    worksheet.write(0,count_column,'url',format2)
    worksheet.write(1,count_column,'Ссылка на сайте поставщика',format)
    count_column+=1
    #photos
    count_photo.times{|i|
      worksheet.write(0,count_column,'images'+i.to_s,format2)
      worksheet.write(1,count_column,'Фото '+i.to_s,format)
      count_column+=1
    }

    count_row=2
    @shop.products.each { |p|
      count_column=0
      worksheet.write(count_row,count_column,p.main_categories,format2)
      count_column+=1
      worksheet.write(count_row,count_column,p.category_path,format2)
      count_column+=1
      worksheet.write(count_row,count_column,p.title,format2)
      count_column+=1
      worksheet.write(count_row,count_column,p.article,format2)
      count_column+=1
      if count_price>0
        beg_pr=count_column
        p.prices.map{|price|
        worksheet.write(count_row,count_column,price.cost,format2)
        count_column+=1
        }
        count_column=beg_pr+count_price if count_column-count_price!=beg_pr
      end
      worksheet.write(count_row,count_column,p.size,format2)
      count_column+=1
      worksheet.write(count_row,count_column,p.color,format2)
      count_column+=1

      #ext prop
      if count_ext_prop>0
        beg_pr=count_column
        p.ext_props.map{|ext|
          worksheet.write(count_row,count_column,ext.value,format2)
          count_column+=1
        }
        count_column=beg_pr+count_ext_prop if count_column-count_ext_prop!=beg_pr
      end
      worksheet.write(count_row,count_column,p.description,format2)
      count_column+=1
      worksheet.write(count_row,count_column,p.url,format2)
      count_column+=1
      #photos
      if count_photo>0
        p.photos.map{|photo|
          worksheet.write(count_row,count_column,photo.url,format2)
          count_column+=1
        }
      end
      count_row+=1
    }

    # write to file
    workbook.close
    return @shop.title+'.xls'
  end

  def xlsx(shop_id)

  end
end