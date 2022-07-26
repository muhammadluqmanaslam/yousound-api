module Api::V2
    class SubscriptionController < ApiController
        # skip_before_action :authenticate_token!, only: [:new_sub]
        skip_after_action :verify_authorized
        skip_after_action :verify_policy_scoped

        swagger_controller :subscription, 'subscription'


        swagger_api :create do |api|
            summary 'create subscription'
            param :form, "price_id", :string, :required
        end
        def create
            render_error 'price_id parameter is required', :unprocessable_entity and return if params[:price_id].blank?

            Rails.logger.info("==price_id===")
            Rails.logger.info(params[:price_id])
            Rails.logger.info(current_user.id)
            price_param = params[:price_id]
            begin
                if current_user.stripe_customer_id == nil
                    customer = Stripe::Customer.create({
                        email: current_user.email,
                        name: current_user.name,
                    })
                    Rails.logger.info("==customer===")
                    Rails.logger.info(customer)
                    StripeResponse.create({
                        user_id: current_user.id,
                        response: customer.to_json
                    })
                    current_user.stripe_customer_id = customer.id
                    current_user.save
                end
                
                if current_user.stripe_customer_id.present?
                    subscription = Stripe::Subscription.create({
                        customer: current_user.stripe_customer_id,
                        items: [
                            {price: price_param},
                        ],
                        trial_period_days: 30
                    })
                    Rails.logger.info("==subscription===")
                    Rails.logger.info(subscription)
                    
                    if subscription.id.present?
                        current_user.stripe_subscription_id = subscription.id
                        current_user.save
                    end
                    
                end
                StripeResponse.create({
                    user_id: current_user.id,
                    response: subscription.to_json
                })
                render_success(message: "Subscribed successfully.")

            rescue => e
                Rails.logger.info(e.message)
                render_success(error: e.message)
            end
        end
    end
end
