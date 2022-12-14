class CollectionPlaylistSerializer < ActiveModel::Serializer
  attributes :id, :name, :playlist_public, :user_id, :playlist_type
end
