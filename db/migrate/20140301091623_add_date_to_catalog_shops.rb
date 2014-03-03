class AddDateToCatalogShops < ActiveRecord::Migration
  def change
    add_column :catalog_shops, :time_download, :time
    add_column :catalog_shops, :date_last_download, :datetime
  end
end
