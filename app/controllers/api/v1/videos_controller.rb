module Api::V1
  class VideosController < ApiController
    before_action :set_stream, only: [
      :update, :destroy, :similars
    ]

    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def index
      streams = Stream.where(
        user_id: current_user.id,
        video_type: Stream.video_types[:uploaded],
        status: Stream.statuses[:archived]
      ).order(created_at: :desc)

      render_succss ActiveModelSerializers::SerializableResource.new(
        streams,
        each_serializer: StreamSerializer,
        scope: OpenStruct.new(current_user: current_user)
      )
    end

    def create
      # unless params[:stream][:video].instance_of? ActionDispatch::Http::UploadedFile
      #   render_error 'Please attach a video file', :unprocessable_entity and return
      # end

      @stream = Stream.new(
        user: current_user,
        status: Stream.statuses[:active]
      )

      genre_id = params[:stream][:genre_id]
      view_price = params[:stream][:view_price].to_i rescue 0
      viewers_limit = params[:stream][:viewers_limit].to_i rescue 0
      creator_recoup_cost = params[:stream][:creator_recoup_cost].to_i rescue 0
      account_ids = params[:stream][:account_ids].split(',').map{|v| v.strip.to_i} rescue []
      duration = params[:stream][:duration].to_i rescue 0
      upload_url = ''

      render_error 'Required duration', :unprocessable_entity and return unless duration > 0

      begin
        mux = Services::Mux.new
        res = mux.createUploadUrl
        Rails.logger.info('*** *** ***')
        Rails.logger.info(res)

        upload_url = res['data']['url']
        upload_id = res['data']['id']
        # url = URI.parse(upload_url)
        # File.open(params[:stream][:video].path) do |file|
        #   req = Net::HTTP::Put::Multipart.new url.path,
        #     "file" => UploadIO.new(params[:stream][:video].tempfile, model_params[:avatar].content_type, model_params[:avatar].original_filename)
        #   res = Net::HTTP.start(url.host, url.port, url_ssl: true) do |http|
        #     http.request(req)
        #   end
        # end

        # req = Net::HTTP::Put.new url.path,
        #   UploadIO.new(
        #     params[:stream][:video].tempfile,
        #     params[:stream][:video].content_type,
        #     params[:stream][:video].original_filename
        #   )
        # res = Net::HTTP.start(url.host, url.port, url_ssl: true) do |http|
        #   http.request(req)
        # end
        # Rails.logger.info('+++ +++ +++')
        # Rails.logger.info(res)
        # res = mux.getUploadInfo(upload_id)
        # Rails.logger.info('--- --- ---')
        # Rails.logger.info(res)
        # res = mux.getAsset(res['data']['asset_id'])
        # Rails.logger.info('=== === ===')
        # Rails.logger.info(res)

        playback1_id = res['data']['playback_ids'][0]['id'] rescue ''
        playback2_id = res['data']['playback_ids'][1]['id'] rescue ''
        @stream.assign_attributes(
          video_type: Stream.video_types[:uploaded],
          name: params[:stream][:name],
          description: params[:stream][:description] || '',
          genre_id: genre_id,
          view_price: view_price,
          viewers_limit: viewers_limit,
          cover: params[:stream][:cover],
          ml_channel_id: res['data']['id'],
          ml_input_id: res['data']['stream_key'],
          ml_input_dest_1_url: 'rtmp://live.yousound.com:5222/app',
          ml_input_dest_2_url: 'rtmp://live.yousound.com:433/app',
          mp_channel_1_ep_1_id: playback1_id,
          mp_channel_1_ep_1_url: playback1_id.blank? ? '' : "https://stream.mux.com/#{playback1_id}.m3u8",
          mp_channel_2_ep_1_id: playback2_id,
          mp_channel_2_ep_1_url: playback2_id.blank? ? '' : "https://stream.mux.com/#{playback2_id}.m3u8",
          mp_channel_2_id: upload_id,
          mp_channel_2_url: upload_url,
          cf_domain: nil,
          account_ids: account_ids,
          remaining_seconds: -1,
          digital_content: params[:stream][:digital_content],
          digital_content_name: params[:stream][:digital_content_name],
          duration: duration,
          status: Stream.statuses[:uploading]
        )
        if params[:stream][:assoc_type].present? && params[:stream][:assoc_id].present?
          @stream.assoc_id = params[:stream][:assoc_id]
          @stream.assoc_type = params[:stream][:assoc_type]
        end

        obj = {}
        collaborators = []
        collaborator = nil
        unless params[:stream][:collaborators].blank?
          begin
            data = JSON.parse(params[:stream][:collaborators])
            obj = data.inject({}){|o, c| o[c['user_id']] = c; o}
            collaborators = User.where(id: obj.keys)
          rescue => ex
          end
        end

        total_collaborators_share = 0
        collaborators.each do |collaborator|
          total_collaborators_share += obj[collaborator.id]['user_share']
        end
        creator_share = 100 - total_collaborators_share
        creator_recoup_cost = 0 if creator_recoup_cost < 0
        render_error 'Total share shoud not be greater than 100', :unprocessable_entity and return if creator_share < 0

        @stream.collaborators_count = collaborators.size

        @stream.save!

        UserStream.create(
          user_id: current_user.id,
          stream_id: @stream.id,
          user_type: UserStream.user_types[:creator],
          user_share: creator_share,
          recoup_cost: creator_recoup_cost,
          status: UserStream.statuses[:accepted]
        )

        # message_body = "#{current_user.display_name} wants to upload this stream collaboration"
        collaborators.each do |collaborator|
          UserStream.create(
            user_id: collaborator.id,
            stream_id: @stream.id,
            user_type: UserStream.user_types[:collaborator],
            user_share: obj[collaborator.id]['user_share'],
            status: UserStream.statuses[:accepted]
          )
        end
      rescue => e
        render_error e.message, :unprocessable_entity and return
      end

      # render json: @stream,
      #   serializer: StreamSerializer,
      #   scope: OpenStruct.new(current_user: current_user)
      render json: {
        url: upload_url
      }
    end

    ## use "PATCH streams/:id"
    # def update
    # end

    ## use "DELETE streams/:id"
    # def destroy
    #   render_error 'Not allowed', :unprocessable_entity and return unless current_user.admin? || current_user.id == @stream.user_id
    # end

    def similars
      skip_authorization

      count = param[:count].to_id rescue 4

      streams = Stream.where(
        status: [ Stream.statuses[:running], Stream.statuses[:archived] ],
        genre_id: @stream.genre_id
      )

      render_success ActiveModel::SerializableResource.new(
        streams,
        each_serializer: StreamSerializer,
        scope: OpenStruct.new(current_user: current_user)
      )
    end

    private
    def set_stream
      @stream = Stream.find_by!(
        id: params[:id],
        status: Stream.statuses[:archived]
      )
    end
  end
end
