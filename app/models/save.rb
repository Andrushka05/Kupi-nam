require 'rubygems'
require 'roo'

class Save
  def xls(shop_id)
    @shop=Shop.find(shop_id)
    s = Excel.new(@shop.title+".xls")
    s.default_sheet = s.sheets.first
    #max count prices
    count_price=0
    @shop.products.each { |x| x.prices.each { |price| } }
    #max count photos
    @shop.products.each { |p| p. }
  end

  def xlsx(shop_id)
    s = Excelx.new("myspreadsheet.xlsx")
    s.default_sheet = s.sheets.first
  end
end