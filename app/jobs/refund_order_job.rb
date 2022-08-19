class RefundOrderJob < ApplicationJob
  queue_as :default

  def perform
    orders = ShopOrder.where("status = :status AND updated_at <= :updated_at", { status: "order_pending", updated_at: 1.days.ago.beginning_of_day})
    if orders.present?
      orders.each do |order|
        if order.items.present? 
          order.items.each do |item|
            Rails.logger.info("order payment id==" + order.id.to_s)
            Rails.logger.info("digital content====" + item.id.to_s + item.product.digital_content.to_s)
            if item.product.digital_content == '' and item.stripe_charge_id != ''
              refund_response = Stripe::Refund.create({
                charge: item.payment_token,
              })
              Rails.logger.info("===refund_response===")
              Rails.logger.info(refund_response)
              if refund_response.status == "succeeded"
                item.status = "refunded"
                item.refund_amount = refund_response.amount
                order.payment_id = refund_response.id
                order.status = "order_refunded"
              end
              order.stripe_response.present? ? order.stripe_response + refund_response.to_json : order.stripe_response
              item.save
              order.save
            else
              Rails.logger.info("===else refund not required===")
              Rails.logger.info("item id===" + item.id.to_s)
              Rails.logger.info("order payment id==" + order.payment_token)
            end
          end
        end
      end
    end
  end
end
