class Collection < ApplicationRecord
  belongs_to :user
  belongs_to :album
  belongs_to :track
  belongs_to :stream
  belongs_to :shop_product
end
