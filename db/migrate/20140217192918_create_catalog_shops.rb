class CreateCatalogShops < ActiveRecord::Migration
  def change
    create_table :catalog_shops do |t|
      t.string :title
      t.string :url
      t.time :time_download
      t.datetime :date_last_download
      t.references :shop, index: true

      t.timestamps
    end
  end
end
