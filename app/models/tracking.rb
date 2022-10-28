class Tracking < ApplicationRecord
  belongs_to :creator, class_name: 'User'
  belongs_to :listener, class_name: 'User'

  belongs_to :stream
  belongs_to :track

  def self.most_listened_creators(listener)
    trackings =  Tracking.joins(:creator).includes(:creator)
      .where("trackings.listener_id = ? and trackings.active = ? and
        users.payment_account_id IS NOT NULL", listener.id, true)
    play = count_plays(trackings)
    playedViewed = play.pluck(:playedViewed)
    if playedViewed.first(10).uniq.length != playedViewed.first(10).length
      play = duration_count(trackings, play)
      duration = play.pluck(:duration)
      if duration.first(10).uniq.length != duration.first(10).length
        play = upload_counts(trackings, play)
        uploads = play.pluck(:uploads)
        if uploads.first(10).uniq.length != uploads.first(10).length
          play = creators_signup_date(trackings, play)
        end
      end
    end
    return play
  end

  def self.count_plays(trackings)
    played_count = trackings.group("creator_id").count
    played_count = played_count.sort {|a1,a2| a2[1]<=>a1[1]}.to_h #Most listened artists stayed on top
    play = []
    played_count.keys.each do |creator_id|
      username = trackings.select { |t| t.creator_id == creator_id}&.first&.creator&.username
      play.push(
        user: username,
        playedViewed: played_count[creator_id],
        subscriptionShare: share_calculate(played_count),
        id: creator_id
      )
    end

    play
  end

  def self.duration_count(trackings, play)
    play.each do |record|
      tracks = trackings.select{|t| t[:creator_id] == record[:id]}
      record[:duration] = tracks.pluck(:duration).inject(:+)
    end

    # sorting hash on the basis of playedViewed Times first and then on the basis of duration
    play = play.sort { |a, b| [a[:playedViewed], a[:duration]] <=> [b[:playedViewed], b[:duration]] }
    play.reverse
  end

  def self.upload_counts(trackings, play)
    play.each do |record|
      streams_count = Stream.where(user_id: record[:id]).count
      tracks_count = Track.where(user_id: record[:id]).count

      record[:uploads] = streams_count + tracks_count
    end

    play = play.sort { |a, b| [a[:playedViewed], a[:duration], a[:uploads]] <=> [b[:playedViewed], b[:duration], b[:uploads]] }
    play.reverse
  end

  def self.creators_signup_date(trackings, play)
    play.each do |record|
      signup_date = trackings.select{|t| t.creator_id == record[:id]}.first&.creator&.created_at
      record[:signup_date] = signup_date
    end

    play = play.sort { |a, b| [a[:playedViewed], a[:duration], a[:uploads], b[:signup_date]] <=> [b[:playedViewed], b[:duration], b[:uploads], a[:signup_date]] }
    play.reverse
  end

  def self.share_calculate(played_count)
    return 0.5 if played_count.length >= 10

    (5.to_f/played_count.length).round(3).to_s[0..3].to_f
  end

  def self.stripe_funds_transfer(user)
    play = most_listened_creators(user)
    users = User.where(id: play.pluck(:id))
    play.each do |record|
      Stripe::Transfer.create(
        amount: (record[:subscriptionShare]*100).to_i,
        currency: 'usd',
        destination: users.select{|u| u.id == record[:id]}.first&.payment_account_id
      )
    end
  end
end

