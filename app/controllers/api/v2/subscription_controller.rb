module Api::V2
    class SubscriptionController < ApiController
        # skip_before_action :authenticate_token!, only: [:new_sub]
        skip_after_action :verify_authorized
        skip_after_action :verify_policy_scoped

        swagger_controller :subscription, 'subscription'


        swagger_api :create do |api|
            summary 'create subscription'
            param :form, "price_id", :string, :required
            param :form, "token_id", :string, :required
            param :form, "token_response", :string, :optional
        end
        def create
            render_error 'price_id parameter is required', :unprocessable_entity and return if params[:price_id].blank?
            render_error 'token_id parameter is required', :unprocessable_entity and return if params[:token_id].blank?

            Rails.logger.info("==price_id===")
            Rails.logger.info(params[:price_id])
            Rails.logger.info("==token_id===")
            Rails.logger.info(params[:token_id])
            Rails.logger.info("==token_response===")
            Rails.logger.info(params[:token_response])
            price_param = params[:price_id]
            begin
                StripeResponse.create({
                    user_id: current_user.id,
                    response: params[:token_response],
                    response_type: 'CreateToken from frontend'
                })
                if current_user.stripe_customer_id == nil
                    payment_method = Stripe::PaymentMethod.create({
                    type: 'card',
                    card: {
                        token: params[:token_id]
                    },
                    })
                    StripeResponse.create({
                        user_id: current_user.id,
                        response: payment_method.to_json,
                        response_type: 'PaymentMethod.create'
                    })
                    payment_method_id = payment_method.id if payment_method.id.present?
                    customer = Stripe::Customer.create({
                        email: current_user.email,
                        name: current_user.name,
                        payment_method: payment_method_id,
                    })
                    Rails.logger.info("==customer===")
                    Rails.logger.info(customer)
                    StripeResponse.create({
                        user_id: current_user.id,
                        response: customer.to_json,
                        response_type: 'Customer.create'
                    })
                    current_user.plan = price_param
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
                        current_user.plan = price_param
                        current_user.creator_verified = true if current_user.user_type != 'listener'
                        current_user.stripe_subscription_id = subscription.id
                        current_user.save

                        StripeResponse.create({
                            user_id: current_user.id,
                            response: subscription.to_json,
                            response_type: 'Subscription.create'
                        })
                    end
                end
                
                render_success(message: "Subscribed successfully.")

            rescue => e
                Rails.logger.info(e.message)
                render_success(error: e.message)
            end
        end

        def creator_verified
            user = User.find_by_id(params[:user_id])
            render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin? || current_user.moderator?

            if user.stripe_customer_id.present? && params["verify_creator"] == "approve"
                subscription = Stripe::Subscription.create({
                    customer: user.stripe_customer_id,
                    items: [
                        {price: user.plan},
                    ],
                    trial_period_days: 30
                })

                if subscription.id.present?
                    user.creator_verified = true
                    user.stripe_subscription_id = subscription.id
                    user.save

                    StripeResponse.create({
                        user_id: user.id,
                        response: subscription.to_json,
                        response_type: 'Subscription.create'
                    })
                    render_success "Successfully approve the creator account."
                end
            elsif params["verify_creator"] == "reject"
                user.creator_verified = nil
                user.user_type = "listener"
                user.save
            else
                render_error 'Something went wrong', :unprocessable_entity
            end
        end

        def free_account_credit
            user = User.find_by_id(params[:id])
            render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin? || current_user.moderator?
            subscription_id = user.stripe_subscription_id
            if params[:free_credit_month].present? && subscription_id.present?
                trial_update = params[:free_credit_month] == "Forever" ?
                    Time.new + 728.days : Time.new + params[:free_credit_month].to_i.months
                response = Stripe::Subscription.update(user.stripe_subscription_id, trial_end: trial_update.to_i)
                render_success success_response: "Trial of #{user.username} has been updated to #{trial_update}."
            else
                render_error 'Something went wrong.', :unprocessable_entity and return unless params[:free_account_credit].present?
            end
        end
    end
end
