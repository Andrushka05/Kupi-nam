class CreateProducts < ActiveRecord::Migration
  def change
    create_table :products do |t|
      t.string :title
      t.string :color
      t.string :article
      t.string :size
      t.string :category_path
      t.text :description
      t.string :state
      t.string :main_categories
      t.string :client_prices
      t.string :article2
      t.string :url
      t.references :shop, index: true
      t.references :catalog_shop, index: true

      t.timestamps
    end
  end
end
