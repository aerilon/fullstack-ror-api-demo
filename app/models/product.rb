class Product < ApplicationRecord
  validates :asin, presence: true
end
