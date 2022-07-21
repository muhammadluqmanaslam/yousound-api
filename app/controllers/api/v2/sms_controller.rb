module Api::V2
    class SmsController < ApiController
        # skip_before_action :authenticate_token!, only: [:sms_send]
        skip_after_action :verify_authorized
        skip_after_action :verify_policy_scoped

        swagger_controller :sms, 'sms'


        swagger_api :sms_send do |api|
            summary 'send sms'
            param :form, "message", :string, :required
        end
        def sms_send
            render_error 'message parameter is required', :unprocessable_entity and return if params[:message].blank?
            render_error 'message characters must be less than 151', :unprocessable_entity and return if params[:message].size > 150

            followers_count = current_user.followers_count
            Rails.logger.info("==followers_count===")
            Rails.logger.info(followers_count)
            if followers_count > 0
                followers = current_user.followers
                account_sid = ENV['TWILIO_ACCOUNT_SID'] # Your Test Account SID from www.twilio.com/console/settings
                auth_token = ENV['TWILIO_AUTH_TOKEN']   # Your Test Auth Token from www.twilio.com/console/settings
                begin
                    Rails.logger.info(followers)
                    for follower in followers do
                        Rails.logger.info(follower.username)
                        @client = Twilio::REST::Client.new account_sid, auth_token
                        message = @client.messages.create(
                            body: params[:message],
                            to: "+923004930505",    # Replace with your phone number
                            from: "+18608912141")  # Use this Magic Number for creating SMS
                        Rails.logger.info("message sid===")
                        Rails.logger.info(message.sid)
                        @client = nil
                        if message.sid.present?
                            SmsMessage.create(
                                user_id: current_user.id,
                                sent_to_id: follower.id,
                                message: params[:message],
                                message_sid: message.sid
                            )
                        end
                    end
                    render_success(message: "SMS has been sent.")
                rescue => e
                    puts (e.message)
                    Rails.logger.info(e.message)
                    render_success(e.message)
                end
            else
                render_success(message: "No followers found.")
            end
            
        end

        swagger_api :index do |api|
            summary 'list sms'
        end
        def index
            smsList = SmsMessage.where(user_id: current_user.id).order(created_at: 'DESC')
            render_success smsList
        end
    end
end
