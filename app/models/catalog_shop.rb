class CatalogShop < ActiveRecord::Base
  has_many :products
  belongs_to :shop
end
