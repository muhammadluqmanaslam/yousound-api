class RefundOrderJob < ApplicationJob
  queue_as :default

  def perform
    orders = ShopOrder.where("status = :status AND updated_at <= :updated_at", { status: "order_pending", updated_at: 3.days.ago.beginning_of_day}).order('updated_at DESC')
    if orders.present?
      orders.each do |order|
        if order.items.present? 
          order.items.each do |item|
            Rails.logger.info("order id==" + order.id.to_s)
            Rails.logger.info("payment_token condition====" + order.payment_token.to_s)
            Rails.logger.info("payment table charge id===" + order.payments[0].payment_token.to_s)
            if (item.product.digital_content_name == nil or item.product.digital_content_name == '') and order.payment_token.present?
              Rails.logger.info("====in if condition====")
              refund_response = Stripe::Refund.create({
                payment_intent: order.payments[0].payment_token,
              })
              Rails.logger.info("===refund_response===")
              Rails.logger.info(refund_response)
              StripeResponse.create({
                  user_id: order.customer_id,
                  response: refund_response.to_json,
                  response_type: 'Refund.create for order id '+ order.id.to_s
              })
              if refund_response.status == "succeeded"
                item.status = "refunded"
                item.refund_amount = refund_response.amount
                order.payment_id = refund_response.id
                order.status = "order_refunded"
              end
              order.stripe_response.present? ? order.stripe_response + refund_response.to_json : order.stripe_response
              item.save
              order.save
              
              Rails.logger.info("=== Refunded ===")
              Rails.logger.info("item id===" + item.id.to_s)
              Rails.logger.info("order payment id==" + order.payment_token.to_s)
            else
              Rails.logger.info("===else refund not required===")
            end
          end
        end
      end
    end
  end
end
