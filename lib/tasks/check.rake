namespace :db do
  desc 'Check user balance to the payment records'
  task :check_user_balance => :environment do
    puts 'Checking user balance...'
    User.all.each do |user|
      # result = ActiveRecord::Base.connection.exec_query(
      #   "SELECT SUM(received_amount) AS total_received_amount "\
      #   "FROM payments WHERE receiver_id = '#{user.id}'"
      # ).first
      # total_received_amount = result['total_received_amount']

      total_received_amount = Payment.where(receiver_id: user.id).sum(:received_amount)
      total_sent_amount = Payment.where(sender_id: user.id).sum(:sent_amount)

      if user.balance_amount != total_received_amount - total_sent_amount
        puts "#{user.id} \t| #{user.email} \t| #{user.balance_amount} | #{total_received_amount} | #{total_sent_amount}"
      end
    end
    puts 'Checked'
  end

  desc 'Fix user balance based on the payment records'
  task :fix_user_balance => :environment do
    puts 'Fixing user balance...'
    # site_deposit_amount = Payment.where('sender_id = receiver_id AND payment_type = ?', Payment.payment_types[:deposit]).sum(:received_amount)
    # site_withdraw_amount = Payment.where('sender_id = receiver_id AND payment_type = ?', Payment.payment_types[:withdraw]).sum(:sent_amount)
    # site_balance = User.sum(:balance_amount)
    # puts "NOT EQUAL" and return unless site_balance != site_deposit_amount - site_withdraw_amount
    User.all.each do |user|
      total_received_amount = Payment.where(receiver_id: user.id).sum(:received_amount)
      total_sent_amount = Payment.where(sender_id: user.id).sum(:sent_amount)

      if user.balance_amount != total_received_amount - total_sent_amount
        puts "#{user.id} \t| #{user.email} \t| #{user.balance_amount} | #{total_received_amount} | #{total_sent_amount}"
        user.update_attributes(balance_amount: total_received_amount - total_sent_amount)
      end
    end
    puts 'Fixed'
  end

  desc 'Fix payments refund amount'
  task :fix_refund_amount => :environment do
    puts 'Fixing refund amount...'
    Payment.update_all(refund_amount: 0)
    Payment.where(payment_type: Payment.payment_types[:refund]).each do |refund_payment|
      payment = refund_payment.assoc
      if payment.present?
        payment.update_attributes(refund_amount: payment.refund_amount + refund_payment.sent_amount)
        puts "#{refund_payment.id} -> #{payment.id} : #{payment.refund_amount}"
      end
    end
    puts 'Fixed'
  end

  desc 'Fix order status'
  task :fix_order_status => :environment do
    puts 'Fixing order status...'
    ShopItem.joins(:product => [:category]).where(
      status: ShopItem.statuses[:item_ordered],
      shop_categories: {
        is_digital: true
      }
    ).update_all(status: ShopItem.statuses[:item_shipped])
    # ShopOrder.includes(:items).find_each do |order|
    #   if order.order_shipped?
    #     unless order.items.where.not(status: ShopItem.statuses[:item_shipped]).size == 0
    #       order.order_pending!
    #       puts "#{order.id} : order_shipped -> order_pending"
    #     end
    #   else
    #     if order.items.where.not(status: ShopItem.statuses[:item_shipped]).size == 0
    #       order.order_shipped!
    #       puts "#{order.id} : order_pending -> order_shipped"
    #     end
    #   end
    # end
    ShopOrder.includes(:items).find_each do |order|
      if order.order_shipped?
        unless order.items.select{ |item| item.status != 'item_shipped' }.blank?
          order.order_pending!
          puts "#{order.id} : order_shipped -> order_pending"
        end
      else
        if order.items.select{ |item| item.status != 'item_shipped' }.blank?
          order.order_shipped!
          puts "#{order.id} : order_pending -> order_shipped"
        end
      end
    end
    puts 'Fixed'
  end

  desc 'Clean tracks which never used'
  task :clean_tracks => :environment do
    puts 'Cleaning tracks which never used...'
    Track.joins('LEFT JOIN albums_tracks at ON at.track_id = tracks.id').where('at.album_id IS NULL').each do |track|
      track.destroy
    end
    puts 'Cleaned'
  end

  desc 'Set origianl album to tracks'
  task :set_album_to_tracks => :environment do
    puts 'Assigning original album to the tracks...'
    Track.where(album_id: nil).each do |track|
      album = Album.joins('LEFT JOIN albums_tracks at ON at.album_id = albums.id').where(
        at: { track_id: track.id },
        album_type: Album.album_types[:album]
      ).order('albums.created_at ASC').first

      track.update(album_id: album.id) if album.present?
    end
    puts 'Assigned'
  end

  desc 'Set origianl albums gradient colors'
  task :fetch_hex_for_albums => :environment do

    Album.all.each_with_index do |album, index|
      begin
        uri = URI(album.cover.url)
        resp = Net::HTTP.get_response(uri)
        this_file = "tempCover_#{index}.png"
        if resp.body.include?('Error')
          album.update(gradient_color: "#3d1403")
          next
        end
        f = File.open(this_file, 'wb+'){|f| f.write(resp.body)}
        image = MiniMagick::Image.open(this_file)
        result = image.run_command('convert', this_file, '-format', '%c', '-colors', 1, '-depth', 8, 'histogram:info:')
      
        # Extract colors and frequencies from result
        frequencies = result.scan(/([0-9]+)\:/).flatten.map { |m| m.to_f }
        hex_values = result.scan(/(\#[0-9ABCDEF]{6,8})/).flatten
        if hex_values.present?
          album.update(gradient_color: hex_values.first)
          File.delete(this_file) if File.exist?(this_file)
          puts " ========== gradient color #{album.gradient_color}"
        else
          album.update(gradient_color: "#3d1403")
        end
        # this_file.
      rescue => e
        puts "Exce: #{e}"
        album.update(gradient_color: "#3d1403")
      end
    end
  end

  desc 'Set origianl product gradient colors'
  task :fetch_hex_for_products => :environment do

    ShopProduct.all.each_with_index do |product, index|
      begin
        uri = URI(product.covers.first.cover.url)
        resp = Net::HTTP.get_response(uri)
        this_file = "tempCover_#{index}.png"
        if resp.body.include?('Error')
          product.update(gradient_color: "#3d1403")
          next
        end
        f = File.open(this_file, 'wb+'){|f| f.write(resp.body)}
        image = MiniMagick::Image.open(this_file)
        result = image.run_command('convert', this_file, '-format', '%c', '-colors', 1, '-depth', 8, 'histogram:info:')
      
        # Extract colors and frequencies from result
        frequencies = result.scan(/([0-9]+)\:/).flatten.map { |m| m.to_f }
        hex_values = result.scan(/(\#[0-9ABCDEF]{6,8})/).flatten
        if hex_values.present?
          product.update(gradient_color: hex_values.first)
          File.delete(this_file) if File.exist?(this_file)
          puts " ========== gradient color #{product.gradient_color}"
        else
          product.update(gradient_color: "#3d1403")
        end
        # this_file.
      rescue => e
        puts "Exce: #{e}"
        product.update(gradient_color: "#3d1403")
      end
    end
  end
end
