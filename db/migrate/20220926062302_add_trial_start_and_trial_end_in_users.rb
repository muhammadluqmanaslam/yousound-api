class AddTrialStartAndTrialEndInUsers < ActiveRecord::Migration[5.0]
  def up
    add_column :users, :trial_start, :datetime
    add_column :users, :trial_end, :datetime
    users = User.where.not(stripe_subscription_id: nil)
    users.each do|user|
      begin
        stripe_response = Stripe::Subscription.retrieve(user.stripe_subscription_id)
        user.trial_start = Time.at(stripe_response.trial_start) if stripe_response.trial_start.present?
        user.trial_end = Time.at(stripe_response.trial_end) if stripe_response.trial_end.present?
        user.plan = stripe_response.plan.id if ['basic', 'plus', 'pro'].include?(stripe_response.plan.id)
        if (['artist', 'brand']).include?(user.user_type)
          user.creator_verified = true
        end
        user.save!
      rescue Stripe::InvalidRequestError
        user.update(stripe_subscription_id: nil)
      end
    end
  end

  def down
    remove_column :users, :trial_start
    remove_column :users, :trial_end
  end
end
