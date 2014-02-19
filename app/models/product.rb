class Product < ActiveRecord::Base
  has_many :photos
  has_many :prices
  belongs_to :shop
  belongs_to :catalog_shop
  has_many :ext_props
end
