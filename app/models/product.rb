class Product < ActiveRecord::Base
  has_many :prices
  has_many :photos
  belongs_to :shop
  belongs_to :catalog_shop
end
