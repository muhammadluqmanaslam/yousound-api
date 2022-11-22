class WebhookController < ApplicationController
	require 'stripe'
	skip_before_action :authenticate_token!
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

	def payment_process
		Rails.logger.info("================== start")
		payload = request.body.read
		event = nil

		begin
			event = Stripe::Event.construct_from(
				JSON.parse(payload, symbolize_names: true)
			)
			# Handle the event
			if event.type == "payment_intent.created"
				payment_intent = event.data.object.id
				if payment_intent.present?
					puts "================== intent #{payment_intent}"
					Rails.logger.info("================== intent #{payment_intent}")
					confirm_payment_intent = Stripe::PaymentIntent.confirm(
						payment_intent,
						{payment_method: 'pm_card_visa'},
					)
					if confirm_payment_intent['status'] == 'succeeded'
						user = User.find_by_stripe_customer_id(event.data.object.customer)
						stripe_subscription = Stripe::Subscription.retrieve(user.stripe_subscription_id)
						user.update(trial_start: Time.at(stripe_subscription.current_period_start),
							trial_end: Time.at(stripe_subscription.current_period_end, trial_complete: true)
						)
						# stripe_funds_transfer(user)
						status 200
					end
				end
			end
		rescue => e
			# Invalid payload
			puts "⚠️  Webhook error while parsing basic request. #{e.message}"
			status 400
			return
		end
	end

	private

	def stripe_funds_transfer(listener_user)
		puts "============= listener #{listener_user}"
		share_payouts = Tracking.most_listened_creators(listener_user).first(10)
		user_ids = share_payouts.pluck(:id)
		share_payouts.each do |record|
			user = User.find(record[:id])
			stripe_fee = Payment.stripe_fee(record[:subscriptionShare] * 100)
			transfer_amount = (record[:subscriptionShare] * 100 - stripe_fee).to_i
			puts "====user_id #{user.id}========== Transfer Amount #{transfer_amount} ==========stripe fee #{stripe_fee}"
			if (user.stripe_connected && transfer_amount > 0)
				stripe_response = Stripe::Transfer.create({
					amount: transfer_amount,
					currency: 'usd',
					destination: user.payment_account_id,
				})

				puts "============== Subscription Share Payouts #{stripe_response}"

				StripeResponse.create({
					user_id: user.id,
					response: stripe_response,
					response_type: 'SubscriptionPayout'
				})
			end
		end
	end
end
