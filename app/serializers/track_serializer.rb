class TrackSerializer < ActiveModel::Serializer
  attributes :id, :slug, :name, :audio, :status, :downloaded, :played, :audio_download_url, :duration
  attribute :user
  attribute :album
  attribute :mux_audio_id_1
  attribute :mux_audio_url_1
  attribute :mux_audio_id_2
  attribute :mux_audio_url_2
  attribute :mp_channel_1_ep_1_id
  attribute :mp_channel_1_ep_1_url
  attribute :mp_channel_2_ep_1_id
  attribute :mp_channel_2_ep_1_url

  def user
    UserSerializer1.new(
      object.user,
      scope: scope,
      include_is_following: instance_options[:include_user_is_following]
    )
  end

  def album
    object.album.as_json(
      only: [ :id, :slug, :name, :cover, :album_type ]
    )
  end

  def include_user?
    instance_options[:include_user] || false
  end
end
