class AudioLocationChangeJob < ApplicationJob
  queue_as :default
  require 'mux_ruby'

  def perform
    tracks = Track.all
    s3 ||= Aws::S3::Resource.new(region: ENV['AWS_REGION'], access_key_id: ENV['AWS_ACCESS_KEY_ID'], secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'])
    updated_tracks = []
    error_tracks = []
    tracks.each do |track|
      begin
        response = s3.bucket(ENV['AWS_S3_BUCKET']).object(track.audio.path)

        if response.exists?
          mux_upload(track, updated_tracks) if track.audio.url.present?
        else
          error_tracks << track.id
          Rails.logger.info("---------------------------- Response not found for Track #{track.id}")
        end
      rescue => e
        error_tracks << track.id
        Rails.logger.info("=================Exception caught for Track #{track.id} = #{e.message}")
      end
    end
    Rails.logger.info("======== Updated Track Ids are = #{updated_tracks}")
    Rails.logger.info("======== Not Updated Track Ids are = #{error_tracks}")
  end

  def mux_upload(track, updated_tracks)
    openapi = mux_configuration
    create_asset_request = MuxRuby::CreateAssetRequest.new
    assets_api = MuxRuby::AssetsApi.new

    create_asset_request = MuxRuby::CreateAssetRequest.new
    create_asset_request.input = [{:url => track.audio.url}]

    asset = assets_api.create_asset(create_asset_request)

    create_playback_request_id = MuxRuby::CreatePlaybackIDRequest.new
    create_playback_request_id.policy = MuxRuby::PlaybackPolicy::PUBLIC
    playback_id = assets_api.create_asset_playback_id(asset.data.id, create_playback_request_id)
    track.update(mux_audio_id_2: asset.data.id,
      mp_channel_1_ep_1_id: playback_id.data.id,
      mp_channel_1_ep_1_url: playback_id.data.id.blank? ? '' : "https://stream.mux.com/#{playback_id.data.id}/audio.m4a"
    )
    updated_tracks << track.id
    Rails.logger.info("---------------------------- Track Id = #{track.id}")
  end

  private

  def mux_configuration
    @openapi ||= MuxRuby.configure do |config|
      config.username = ENV['MUX_TOKEN_ID']
      config.password = ENV['MUX_TOKEN_SECRET']
    end
  end
end
