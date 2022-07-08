class DeleteRepostJob < ApplicationJob
  queue_as :default

  def perform
    feeds = Feed.where("feed_type = :feed_type AND created_at <= :created_at", { feed_type: "repost", created_at: 7.days.ago.beginning_of_day})
    
    if feeds.present?
      feeds.each do |feed|
        if feed.status != 'deleted'
          feed.status = 'deleted'
          feed.save
        end
      end
    end
  end
end
