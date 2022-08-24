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
            render_error 'No followers found.',:unprocessable_entity and return if followers_count <= 0
            # funcation sfsd 
            followers = current_user.followers
            account_sid = ENV['TWILIO_ACCOUNT_SID'] # Your Test Account SID from www.twilio.com/console/settings
            auth_token = ENV['TWILIO_AUTH_TOKEN']   # Your Test Auth Token from www.twilio.com/console/settings
            
                Rails.logger.info(followers)
                failed_sms = 0
                sms_sent = 0
                missing_phone_number = 0
                for follower in followers do
                    Rails.logger.info(follower.username)
                    @client = Twilio::REST::Client.new account_sid, auth_token
                    if follower.phone_number.present?
                        begin
                            message = @client.messages.create(
                            body: params[:message],
                            to: follower.phone_number,    # Replace with your phone number
                            from: ENV["TWILIO_FROM_NO"] || "+14422911621")  # Use this Magic Number for creating SMS
                        
                            Rails.logger.info("message ===")
                            Rails.logger.info(message)
                            @client = nil
                            
                            if message.sid.present?
                                SmsMessage.create(
                                    user_id: current_user.id,
                                    sent_to_id: follower.id,
                                    message: params[:message],
                                    message_sid: message.sid
                                ) 
                                sms_sent += 1
                            end
                        rescue Twilio::REST::RestError => error
                            Rails.logger.info("----Twilio rescue-----")
                            Rails.logger.info(error.message)
                            failed_sms += 1
                            follower.phone_number = nil
                            follower.save
                        rescue => e
                            Rails.logger.info("----last rescue-----")
                            Rails.logger.info(e.message)
                            failed_sms += 1
                            follower.phone_number = nil
                            follower.save
                        end
                    else
                        missing_phone_number += 1
                    end
                end

                missing_msg = missing_phone_number.to_s + " followers don't have valid phone number. " if missing_phone_number > 0
                failed_msg = failed_sms.to_s + " SMS failed due to invalid phone number. " if failed_sms > 0
                sms_sent_msg = ""
                stripe_charge_error_msg = ""
                if sms_sent > 0
                    begin
                        sms_charges = 0.01 * sms_sent
                        chargeRes = Stripe::Charge.create({
                            amount: sms_charges * 100,
                            currency: 'usd',
                            customer: current_user.stripe_customer_id,
                            description: 'SMS Fee from Yousound.',
                            })
                        StripeResponse.create({
                            user_id: current_user.id,
                            response: chargeRes.to_json,
                            response_type: 'Charge.create'
                        })
                        stripe_charge_msg = "Your card charge successfully." if chargeRes.status == 'succeeded' > 0
                    rescue => e
                        Rails.logger.info("----stripe charge rescue-----")
                        Rails.logger.info(e.message)
                        stripe_charge_msg = e.message
                    end
                    sms_sent_msg = "SMS sent successfully to " + sms_sent.to_s + " followers. " + stripe_charge_msg
                end

                final_msg = missing_msg.to_s + failed_msg.to_s + sms_sent_msg.to_s
                render_success(message: final_msg)
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
