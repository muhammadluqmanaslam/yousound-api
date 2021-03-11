require 'net/http/put/multipart'

module Api::V1
  class VideosController < ApiController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def create
      unless params[:stream][:video].instance_of? ActionDispatch::Http::UploadedFile
        render_error 'Please attach a video file', :unprocessable_entity and return
      end

      @stream = Stream.new(
        user: current_user,
        status: Stream.statuses[:active]
      )

      genre_id = params[:stream][:genre_id]
      view_price = params[:stream][:view_price].to_i rescue 0
      viewers_limit = params[:stream][:viewers_limit].to_i rescue 0
      creator_recoup_cost = params[:stream][:creator_recoup_cost].to_i rescue 0
      account_ids = params[:stream][:account_ids].split(',').map{|v| v.strip.to_i} rescue []

      render_error 'Recoup price shoud not be less than $1.00', :unprocessable_entity and return if creator_recoup_cost != 0 && creator_recoup_cost < 100

      begin
        mux = Services::Mux.new
        res = mux.createUploadUrl
        Rails.logger.info('*** *** ***')
        Rails.logger.info(res)

        req_url = res['data']['url']
        upload_id = res['data']['id']
        url = URI.parse(req_url)
        # File.open(params[:stream][:video].path) do |file|
        #   req = Net::HTTP::Put::Multipart.new url.path,
        #     "file" => UploadIO.new(params[:stream][:video].tempfile, model_params[:avatar].content_type, model_params[:avatar].original_filename)
        #   res = Net::HTTP.start(url.host, url.port, url_ssl: true) do |http|
        #     http.request(req)
        #   end
        # end
        req = Net::HTTP::Put::Multipart.new url.path,
          "file" => UploadIO.new(
            params[:stream][:video].tempfile,
            params[:stream][:video].content_type,
            params[:stream][:video].original_filename
          )
        res = Net::HTTP.start(url.host, url.port, url_ssl: true) do |http|
          http.request(req)
        end
        Rails.logger.info('+++ +++ +++')
        Rails.logger.info(res)

        res = mux.getUploadInfo(upload_id)
        Rails.logger.info('--- --- ---')
        Rails.logger.info(res)

        res = mux.getAsset(res['data']['asset_id'])
        Rails.logger.info('=== === ===')
        Rails.logger.info(res)

        playback1_id = res['data']['playback_ids'][0]['id'] rescue ''
        playback2_id = res['data']['playback_ids'][1]['id'] rescue ''
        @stream.assign_attributes(
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
          cf_domain: nil,
          account_ids: account_ids,
          remaining_seconds: -1,
          digital_content: params[:stream][:digital_content],
          digital_content_name: params[:stream][:digital_content_name],
          status: Stream.statuses[:archived]
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

      render json: @stream,
        serializer: StreamSerializer,
        scope: OpenStruct.new(current_user: current_user)
    end

    def update
      authorize @stream

      if params[:stream][:guests_ids].present?
        guests_ids = params[:stream][:guests_ids].split(',').compact
        @stream.guest_list = User.where(id: guests_ids).pluck(:id)
      end

      # extend_period = params[:stream][:extend_period].to_i rescue 0
      # @stream.valid_period += extend_period if extend_period > 0

      @stream.attributes = permitted_attributes(@stream)
      @stream.save!

      # Rails.logger.info("\n\n\n streams/:id/update: #{params[:stream][:assoc_type].present?}, #{params[:stream][:assoc_id].present?}\n\n\n")
      if params[:stream][:assoc_id].present?
        assoc = @stream.assoc

        result = {}
        case assoc.class.name
          when 'Album'
            result = AlbumSerializer.new(assoc).as_json
          when 'ShopProduct'
            result = ShopProductSerializer.new(assoc).as_json
          when 'User'
            result = UserSerializer.new(assoc).as_json
        end
        ActionCable.server.broadcast("stream_#{@stream.id}", {assoc_type: @stream.assoc_type, assoc: result})

        # send push notification to watchers
        data = {
          id: @stream.id,
          user_id: @stream.user_id,
          assoc_type: @stream.assoc_type,
          assoc: Util::Serializer.polymophic_serializer(assoc)
        }

        # user_ids = Activity.where(
        #   action_type: Activity.action_types[:view_stream],
        #   page_track: "#{@stream.class.name}: #{@stream.id}"
        # ).group(:sender_id).pluck(:sender_id)
        now = Time.now
        user_ids = StreamLog.where(
          stream_id: @stream.id,
          updated_at: now.ago(1.minute)..now
        ).pluck(:user_id)

        user_ids << @stream.user_id
        user_ids.uniq!

        PushNotificationWorker.perform_async(
          Device.where(user_id: user_ids).pluck(:token),
          FCMService::push_notification_types[:video_attachment_changed],
          "[#{current_user.display_name}] has updated the video attachment",
          data
        )
      end

      render_success StreamSerializer.new(@stream, scope: OpenStruct.new(current_user: current_user)).as_json
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
