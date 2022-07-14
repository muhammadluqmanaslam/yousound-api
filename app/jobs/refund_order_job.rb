class RefundOrderJob < ApplicationJob
  queue_as :default

  def perform
    orders = ShopOrder.where("status = :status AND updated_at <= :updated_at", { status: "order_pending", updated_at: 21.days.ago.beginning_of_day})
    if orders.present?
      orders.each do |order|
        if order.items.present? 
          order.items.each do |item|
            if item.product.digital_content == nil
              order.status = "order_refunded"
              order.save
              item.status = "refunded"
              refund_amount = (item.amount + item.fee + item.shipping_cost)/100
              item.refund_amount = refund_amount
              item.save
            end
          end
        end
      end
    end
  end
end
