class CollectionPlaylistSerializer < ActiveModel::Serializer
	attributes :id, :name, :playlist_public, :user_id, :playlist_type
	attributes :playlist_details

	def playlist_details
		streams = shop_products = albums = []
		object.playlist_details.each do |item|
			if object.playlist_type == 'tracks'
				albums.push << item.track.album if item.track_id.present?
			elsif object.playlist_type == 'streams'
				streams.push << item.stream if item.stream_id.present?
			elsif object.playlist_type == 'products'
				shop_products.push << item.shop_product if item.shop_product_id.present?
			end
		end

		if object.playlist_type == 'products'
			ActiveModelSerializers::SerializableResource.new(
        shop_products,
        each_serializer: ShopProductSerializer,
        scope: scope
      )
		elsif object.playlist_type == 'tracks'
			ActiveModelSerializers::SerializableResource.new(
        albums,
        each_serializer: AlbumSerializer,
        scope: scope
      )
		elsif object.playlist_type == 'streams'
			ActiveModelSerializers::SerializableResource.new(
        streams,
        each_serializer: StreamSerializer,
        scope: scope
      )
		end
	end
end
