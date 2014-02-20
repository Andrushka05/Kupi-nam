class Product < ActiveRecord::Base
  has_many :photos
  has_many :prices
  has_many :ext_props
  belongs_to :shop
  belongs_to :catalog_shop

end
