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
                    current_user.stripe_customer_id = customer.id
                    current_user.save
                end

                if current_user.stripe_customer_id.present?
                    if current_user.creator_verified.nil? && current_user.user_type != "listener" && current_user.plan != "basic" && price_param != "basic"
                        # creator do signup but he didn't attach his payment details. Now providing payment details
                        current_user.update(creator_verified: false, plan: price_param)
                    elsif current_user.user_type != "listener" && current_user.plan != "basic" && price_param == "basic"
                        # user signup as a creator but now he wants to become listener
                        current_user.update(creator_verified: nil, user_type: 'listener', plan: price_param)
                        subscription = stripe_subscription(current_user.stripe_customer_id, price_param)
                    elsif current_user.user_type == "listener" && current_user.plan == "basic" && price_param != "basic"
                        # Listener wants to become creator for first time
                        current_user.update(user_type: "artist", plan: price_param, creator_verified: false)
                    elsif current_user.user_type != "listener" && current_user.creator_verified == false && current_user.trial_end.present? && current_user.stripe_subscription_id.present?
                        # creator resubscribing again.
                        current_user.update(creator_verified: true)
                        subscription = stripe_subscription(current_user.stripe_customer_id, price_param)
                    elsif current_user.user_type == "listener" && (current_user.plan.nil? || current_user.plan == "basic") && price_param == "basic"
                        #listener normal scenario of subscription
                        current_user.update(plan: "basic")
                        subscription = stripe_subscription(current_user.stripe_customer_id, price_param)
                    end

                    if subscription.id.present?
                        current_user.trial_start = Time.at(subscription.trial_start)
                        current_user.trial_end = Time.at(subscription.trial_end)
                        current_user.deactivate_subscription = false
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
                    StripeResponse.create({
                        user_id: user.id,
                        response: subscription.to_json,
                        response_type: 'Subscription.create'
                    })
                    user.update(creator_verified: true, stripe_subscription_id: subscription.id,
                        trial_start: Time.at(subscription.trial_start), request_status: User.request_statuses[:accepted],
                        trial_end: Time.at(subscription.trial_end), request_role: user.user_type,
                        approver_id: current_user.id, approved_at: Time.now, deactivate_subscription: false)
                    render_success "Successfully approve the creator account."
                end
            elsif params["verify_creator"] == "reject"
                user.update(creator_verified: nil, user_type: "listener",
                    request_role: "listener", request_status: User.request_statuses[:denied])
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
                trial_update = Time.new + 1.day if params[:free_credit_month] == "0"
                response = Stripe::Subscription.update(user.stripe_subscription_id, trial_end: trial_update.to_i)
                user.update(trial_end: trial_update)
                render_success success_response: "Trial of #{user.username} has been updated to #{trial_update.to_date}."
            else
                render_error 'Something went wrong.', :unprocessable_entity and return unless params[:free_account_credit].present?
            end
        end

        def deactivate_subscription
            render_error 'Your account does not have any active subscriptions.', :unprocessable_entity and return if current_user.stripe_subscription_id.blank? || current_user.deactivate_subscription
            stripe_subscription = Stripe::Subscription.retrieve(current_user.stripe_subscription_id)
            if stripe_subscription.present?
                stripe_subscription.delete(at_period_end: true)
                current_user.update(deactivate_subscription: true)
                trial_end = current_user.trial_end.to_date
                ApplicationMailer.cancellation_email_template(current_user).deliver
                render_success success_response: "Your subscription has been successfully cancelled and you can avail the services by the end of #{current_user.trial_end.to_date}."
            else
                render_error 'Something went wrong.', :unprocessable_entity
            end
        end

        private

        def stripe_subscription(stripe_customer_id, plan)
            subscription = Stripe::Subscription.create({
                customer: stripe_customer_id, items: [ { price: plan }, ],
                trial_period_days: 30
            })
        end
    end
end
