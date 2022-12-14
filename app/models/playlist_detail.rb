class PlaylistDetail < ApplicationRecord
  belongs_to :playlist
  belongs_to :track
  belongs_to :stream
  belongs_to :shop_product
end
