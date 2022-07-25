class RefundOrderJob < ApplicationJob
  queue_as :default

  def perform
    orders = ShopOrder.where("status = :status AND updated_at <= :updated_at", { status: "order_pending", updated_at: 21.days.ago.beginning_of_day})
    if orders.present?
      orders.each do |order|
        if order.items.present? 
          order.items.each do |item|
            token = item.payment_token.split("_")
            if item.product.digital_content == nil and token == 'ch'
              order.status = "order_refunded"
              order.save
              refund_response = Stripe::Refund.create({
                charge: item.payment_token,
              })
              Rails.logger.info("===refund_response===")
              Rails.logger.info(refund_response)
              if refund_response.status == "succeeded"
                item.status = "refunded"
                item.refund_amount = refund_response.admount
                item.payment_id = refund_response.id
              end
              item.stripe_response.presets? ? item.stripe_response + refund_response.to_s : item.stripe_response
              item.save
            else
              Rails.logger.info("===payment_token===")
              Rails.logger.info(item.id)
              Rails.logger.info(item.payment_token)
            end
          end
        end
      end
    end
  end
end
