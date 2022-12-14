module Api::V1
  class CollectionPlaylistsController < ApiController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def create
      if params["collection_playlist"]["id"].present?
        @playlist = Playlist.find(params["collection_playlist"]["id"])
        create_playlist_details
        render_success success_response: "Successfully added #{@playlist.playlist_type} in playlist."
      elsif params["collection_playlist"]["id"].blank?
        @playlist = Playlist.new(permit_collection_playlist_params)
        @playlist.save
        create_playlist_details
        render_success success_response: "Successfully added #{@playlist.playlist_type} in playlist."
      else
        render_error('Something went wrong in creating playlist', :unauthorized)
      end
    end

    def fetch_playlist_details
      @playlist = Playlist.find(params[:id])
      if @playlist.playlist_type == 'tracks'
        track_ids = @playlist.playlist_details.pluck(:track_id)
        @tracks = Track.where(id: track_ids)
        render json: {
          tracks: ActiveModelSerializers::SerializableResource.new(
            @tracks,
            each_serializer: TrackSerializer,
            scope: OpenStruct.new(current_user: current_user)
          ),
          playlists: ActiveModelSerializers::SerializableResource.new(
            @playlist,
            each_serializer: CollectionPlaylistSerializer,
            scope: OpenStruct.new(current_user: current_user)
          )
        }
      elsif @playlist.playlist_type == 'streams'
        stream_ids = @playlist.playlist_details.pluck(:stream_id)
        @streams = Stream.where(id: stream_ids)
        render json: {
          streams: ActiveModelSerializers::SerializableResource.new(
            @streams,
            each_serializer: StreamSerializer,
            scope: OpenStruct.new(current_user: current_user)
          ),
          playlists: ActiveModelSerializers::SerializableResource.new(
            @playlist,
            each_serializer: CollectionPlaylistSerializer,
            scope: OpenStruct.new(current_user: current_user)
          )
        }
      elsif @playlist.playlist_type == 'products'
        product_ids = @playlist.playlist_details.pluck(:shop_product_id)
        @shop_products = ShopProduct.where(id: product_ids)
        render json: {
          products: ActiveModelSerializers::SerializableResource.new(
            @shop_products,
            each_serializer: ShopProductSerializer,
            scope: OpenStruct.new(current_user: current_user)
          ),
          playlists: ActiveModelSerializers::SerializableResource.new(
            @playlist,
            each_serializer: CollectionPlaylistSerializer,
            scope: OpenStruct.new(current_user: current_user)
          )
        }
      end
    end

    def index
      @playlists = Playlist.includes(playlist_details: [:track, :shop_product, :stream])
                    .where(user_id: current_user.id)
      streams = []
      shop_products = []
      tracks = []

      @playlists.each do |playlist|
        playlist.playlist_details.each do |playlist_detail|
          streams << playlist_detail.stream_id if playlist_detail.stream_id.present?
          tracks << playlist_detail.track_id if playlist_detail.track_id.present?
          shop_products << playlist_detail.shop_product_id if playlist_detail.shop_product_id.present?
        end
      end

      @streams = Stream.where(id: streams)
      @tracks = Track.where(id: tracks)

      render json: {
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
        playlists: ActiveModelSerializers::SerializableResource.new(
          @playlists,
          each_serializer: CollectionPlaylistSerializer,
          scope: OpenStruct.new(current_user: current_user)
        )
      }
    end

    private

    def permit_collection_playlist_params
      params.require(:collection_playlist).permit(:name, :playlist_public, :playlist_type).merge(user_id: current_user.id)
    end

    def permit_playlist_details_params
      params.permit(:track_id, :stream_id, :playlist_id, :shop_product_id).merge(playlist_id: @playlist&.id)
    end

    def create_playlist_details
      if params["collection_playlist"]["track_ids"].present?
        track_ids = params["collection_playlist"]["track_ids"].split(",")
        playlist_details = []
        playlist_details << (track_ids.map{ |t| PlaylistDetail.new(track_id: t, playlist_id: @playlist.id) })
        PlaylistDetail.import(playlist_details.flatten)
      elsif params["collection_playlist"]["stream_ids"].present?
        stream_ids = params["collection_playlist"]["stream_ids"].split(",")
        playlist_details = []
        playlist_details << (stream_ids.map{ |t| PlaylistDetail.new(stream_id: t, playlist_id: @playlist.id) })
        PlaylistDetail.import(playlist_details.flatten)
      elsif if params["collection_playlist"]["product_ids"].present?
        product_ids = params["collection_playlist"]["product_ids"].split(",")
        playlist_details = []
        playlist_details << (product_ids.map{ |t| PlaylistDetail.new(shop_product_id: t, playlist_id: @playlist.id) })
        PlaylistDetail.import(playlist_details.flatten)
      end
      end
    end
  end
end
