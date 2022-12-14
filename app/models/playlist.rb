class Playlist < ApplicationRecord
  has_many :playlist_details, dependent: :destroy
  belongs_to :user
end
