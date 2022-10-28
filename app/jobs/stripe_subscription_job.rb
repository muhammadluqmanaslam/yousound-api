class StripeSubscriptionJob < ApplicationJob
  queue_as :default
  require 'mux_ruby'

  def perform
    mux_configuration
    users = User.where.not(stripe_subscription_id: nil)
    users.each do |user|
      begin
        stripe_subscription = Stripe::Subscription.retrieve(user.stripe_subscription_id)
        if Time.at(stripe_subscription.trial_end) == user.trial_end
          trial_end = user.trial_end < Date.today
          if trial_end
            user.update(creator_verified: false) if user.stripe_subscription_id.present? && user.plan != 'basic'
            if user.trial_end > Time.new - 38.days
              send_cancellation_email(user)
            elsif user.trial_end > Time.new - 45.days
              delete_user_content(user)
            end
          end
        else
          # subscription updated.
          user.update(trial_start: Time.at(stripe_subscription.trial_start),
            trial_end: Time.at(stripe_subscription.trial_end)
          )
          stripe_funds_transfer
        end
      rescue => ex
        Rails.logger.info("==============Error #{ex}")
      end
    end
  end

  private

  def stripe_funds_transfer(user)
    share_payouts = Tracking.most_listened_creators(user).first(10)
    user_ids = share_payouts.pluck(:id)
    share_payouts.each do |record|
      user = User.find(record[:id])
      stripe_fee = Payment.stripe_fee(record[:subscriptionShare] * 100)
      transfer_amount = (record[:subscriptionShare] * 100 - stripe_fee).to_i
      if (user.stripe_connected && transfer_amount > 0)
        Stripe::Transfer.create({
          amount: transfer_amount,
          currency: 'usd',
          destination: user.payment_account_id,
        })
      end
    end
  end

  def send_cancellation_email(user)
    # ApplicationMailer.cancellation_email_template(user).deliver
  end

  def delete_user_content(user)
    s3 ||= Aws::S3::Resource.new(region: ENV['AWS_REGION'],
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )
    bucket = s3.bucket(ENV['AWS_S3_BUCKET'])

    tracks = Track.where(user_id: user.id)
    aws_content = []
    tracks.each do |track|
      if track.audio.url.present?
        aws_response = bucket.object(track.audio.path)
        aws_content << { key: track.audio.path } if aws_response.exists?
      end
      destroy_mux_content(track.mux_audio_id_1) if track.mux_audio_id_1.present?
    end
    streams = Stream.where(user_id: user.id)
    streams.each do |stream|
      destroy_mux_content(stream.mp_channel_2_id) if stream.mp_channel_2_id.present?
    end
    destroy_aws_content(aws_content, bucket)
  end

  def destroy_aws_content(content, bucket)
    bucket.delete_objects({
      delete:{
        objects: content
      }
    })
  end

  def destroy_mux_content(upload_id)
    @mux ||= Services::Mux.new
    response = @mux.getUploadInfo(upload_id)
    if response.present? && response.parsed_response["data"]["asset_id"].present?
      mux.deleteAsset(response.parsed_response["data"]["asset_id"])
    end
  end

  def mux_configuration
    @openapi ||= MuxRuby.configure do |config|
      config.username = ENV['MUX_TOKEN_ID']
      config.password = ENV['MUX_TOKEN_SECRET']
    end
  end
end
