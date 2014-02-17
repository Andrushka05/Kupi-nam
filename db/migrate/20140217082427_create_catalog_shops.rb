class CreateCatalogShops < ActiveRecord::Migration
  def change
    create_table :catalog_shops do |t|
      t.string :title
      t.references :shop, index: true

      t.timestamps
    end
  end
end
