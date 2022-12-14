module Api::V1
  class CollectionsController < ApiController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def create
      @collection = Collection.new(permit_collection_params)
      if @collection.album_id.blank? && @collection.save
        render_success :true
      elsif @collection.album_id.present?
        @collection.save
        track_ids = Album.find(@collection.album_id).tracks.pluck(:id)
        collections = []
        collections << (track_ids.map{ |t| Collection.new(track_id: t, user_id: current_user.id) })
        Collection.import(collections.flatten)
        render_success :true
      else
        render_error('Something went wrong in creating collection', :unauthorized)
      end
    end

    def index
      @collections = Collection.includes(:track, :stream, :album, :shop_product).where(user_id: current_user.id)
      @tracks = Track.where(id: @collections.pluck(:track_id))
      @streams = Stream.where(id: @collections.pluck(:stream_id).compact)
      @shop_products = ShopProduct.where(id: @collections.pluck(:shop_product_id))
      @albums = Album.where(id: @collections.pluck(:album_id))
      render json: {
        albums: ActiveModelSerializers::SerializableResource.new(
          @albums,
          each_serializer: AlbumSerializer,
          scope: OpenStruct.new(current_user: current_user)
        ),
        streams: ActiveModelSerializers::SerializableResource.new(
          @streams,
          each_serializer: StreamSerializer,
          scope: OpenStruct.new(current_user: current_user)
        ),
        tracks: ActiveModelSerializers::SerializableResource.new(
          @tracks,
          each_serializer: TrackSerializer,
          scope: OpenStruct.new(current_user: current_user)
        ),
        products: ActiveModelSerializers::SerializableResource.new(
          @shop_products,
          each_serializer: ShopProductSerializer,
          scope: OpenStruct.new(current_user: current_user)
        )
      }
    end

    private

    def permit_collection_params
      params.require(:collection)
        .permit(:track_id, :album_id, :stream_id, :shop_product_id).merge(user_id: current_user.id)
    end
  end
end