class CloneDurationFromMuxJob < ApplicationJob
  queue_as :default

  tracks = Track.where.not(mux_audio_id_2: nil)
  updated_tracks = []
  not_updated_tracks = []
  mux = Services::Mux.new
  tracks.each do |track|
    begin
      asset = JSON.parse(mux.getAsset(track.mux_audio_id_2))
      next if asset["error"].present?
      track.update(duration: asset["data"]["tracks"][0]["duration"])
      updated_tracks << track.id
    rescue
      not_updated_tracks << track.id
      puts "Error in cloning track duration = #{track.id}"
    end
  end

  streams = Stream.where.not(mp_channel_1_id: nil)
  updated_streams = []
  not_updated_streams = []
  streams.each do |stream|
    begin
      asset = JSON.parse(mux.getAsset(stream.mp_channel_1_id))
      next if asset["error"].present?
      stream.update(duration: asset["data"]["tracks"][0]["duration"])
      updated_streams << stream.id
    rescue
      not_updated_streams << stream.id
      puts "======== Not Updated Stream Id = #{stream.id}"
    end
  end

  puts "============ Updated tracks #{updated_tracks}"
  puts "============ Not Updated tracks #{not_updated_tracks}"
  puts "============ Updated Streams #{updated_streams}"
  puts "============ Not Updated streams #{not_updated_streams}"
end
