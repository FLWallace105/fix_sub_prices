require 'dotenv'
require 'httparty'

require 'active_record'
require 'sinatra/activerecord'



Dotenv.load
Dir[File.join(__dir__, 'lib', '*.rb')].each { |file| require file }
Dir[File.join(__dir__, 'models', '*.rb')].each { |file| require file }


module FixPrices
    class ThreeItems
        def initialize
            Dotenv.load
            recharge_regular = ENV['RECHARGE_ACCESS_TOKEN']
            recharge_staging = ENV['STAGING_RECHARGE_ACCESS_TOKEN']
            
            
            @my_header = {
              "X-Recharge-Access-Token" => recharge_regular
            }
            @my_change_header = {
              "X-Recharge-Access-Token" => recharge_regular,
              "Accept" => "application/json",
              "Content-Type" =>"application/json"
            }
            @price_should_be = 39.95
            
          end

          def input_three_items
            puts "Hi"
            #my_subs = Subscription.where("created_at < ?", '2019-08-01')
            #my_subs.each do |mys|
            #    puts mys.inspect
            #end
            FixPriceSub.delete_all
            ActiveRecord::Base.connection.reset_pk_sequence!('fix_prices_subs')

            num_price_changes = 0
            CSV.foreach('gabby_csv_input.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
                #puts row.inspect
                customer_id = row['customer_id']
                my_sub = Subscription.where("product_title ilike \'%3%item%\' and customer_id = ? and created_at < ?", customer_id, '2019-08-01').first
                if my_sub != nil
                    puts row.inspect
                    puts my_sub.inspect
                    num_price_changes += 1
                    FixPriceSub.create(subscription_id: my_sub.subscription_id, address_id: my_sub.address_id, customer_id: my_sub.customer_id, created_at: my_sub.created_at, updated_at: my_sub.updated_at, next_charge_scheduled_at: my_sub.next_charge_scheduled_at, cancelled_at: my_sub.cancelled_at,  product_title: my_sub. product_title, price: my_sub.price, quantity: my_sub.quantity, status: my_sub.status, shopify_product_id: my_sub.shopify_product_id, shopify_variant_id: my_sub.shopify_variant_id, sku: my_sub.sku,  order_interval_unit: my_sub. order_interval_unit, order_interval_frequency: my_sub.order_interval_frequency, charge_interval_frequency: my_sub.charge_interval_frequency, order_day_of_month: my_sub.order_day_of_month, order_day_of_week: my_sub.order_day_of_week, raw_line_item_properties: my_sub.raw_line_item_properties, expire_after_specific_number_charges: my_sub.expire_after_specific_number_charges, is_prepaid: my_sub.is_prepaid)
                end


            end
            puts "We have potentially #{num_price_changes} subs to change"

            puts "We have #{FixPriceSub.count} subs to potentially fix prices upon"

          end

          def check_for_current_recharge_price
            puts "Starting ..."
            my_fix_prices = FixPriceSub.where("price_checked_on_recharge = ?", false)
            my_fix_prices.each do |myprice|
                #GET /subscriptions/:id
                puts myprice.inspect
                recharge_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions/#{myprice.subscription_id}", :headers => @my_header,  :timeout => 80)  
                puts recharge_sub_info.inspect 
                if recharge_sub_info.parsed_response['errors']
                    myprice.not_found = true
                    myprice.price_checked_on_recharge = true
                    myprice.save!
                    next
                end
                myprice.price_checked_on_recharge = true
                local_price = recharge_sub_info.parsed_response['subscription']['price']
                puts "local_price = #{local_price}"
                if local_price.to_f > @price_should_be
                    puts "We should update this price on ReCharge"
                    #myprice.price_checked_on_recharge = true
                    myprice.needs_price_updated = true
                    myprice.price_on_recharge = local_price.to_f
                    
                end
                myprice.save!
                recharge_limit = recharge_sub_info.response["x-recharge-limit"]
                determine_limits(recharge_limit, 0.65)
                

            end

          end


          def update_subs_on_recharge
            my_subs_to_update = FixPriceSub.where("needs_price_updated = \'t\' and updated = \'f\' ")

            my_subs_to_update.each do |mys|

                my_now = DateTime.now
                body = { "price" => @price_should_be}.to_json
                
                my_update_sub = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{mys.subscription_id}", :headers => @my_change_header, :body => body, :timeout => 80)
                puts my_update_sub.inspect
                recharge_limit = my_update_sub.response["x-recharge-limit"]
                determine_limits(recharge_limit, 0.65)
                if my_update_sub.code == 200
                    mys.updated = true
                    mys.date_price_updated_at = my_now
                    mys.save!

                else
                    puts "Could not process the subscription id = #{mys.subscription_id}"
                end
               

            end

          end

          def update_one_sub_recharge(sub_id)
            puts "Hi"
            puts "Working on sub_id #{sub_id}"
            
            recharge_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions/#{sub_id}", :headers => @my_header,  :timeout => 80)  
            puts recharge_sub_info.inspect 
            puts "------------------"

            body = { "price" => @price_should_be}.to_json
            my_update_sub = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{sub_id}", :headers => @my_change_header, :body => body, :timeout => 80)
            puts my_update_sub.inspect


          end


          def fix_three_months
            #delete old file
            File.delete('rolled_back_prepaid_subs.csv') if File.exist?('rolled_back_prepaid_subs.csv')
            #Headers for CSV
            column_header = ["subscription_id", "product", "new_price", "recharge_result"]
            CSV.open('rolled_back_prepaid_subs.csv','a+', :write_headers=> true, :headers => column_header) do |hdr|
                column_header = nil


            my_subs_to_update = FixPriceSub.where("needs_price_updated = \'t\' and updated = \'t\' and product_title ilike \'3%Month%\' ")

            my_subs_to_update.each do |mys|

                price = 116.87
                my_title = mys.product_title

                case my_title
                when /\s3\sitems\s\sauto\srenew/i
                    price = 99.85
                when /\s3\sitem/i
                    price = 116.87
                when /\s5\sitem/i
                    price = 124.87
                else
                    price = 116.87
                end
                
                puts "Subscription_id = #{mys.subscription_id} Product = #{my_title} New price = #{price}"

                body = { "price" => price}.to_json
                
                my_update_sub = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{mys.subscription_id}", :headers => @my_change_header, :body => body, :timeout => 80)
                puts my_update_sub.inspect
                recharge_limit = my_update_sub.response["x-recharge-limit"]
                determine_limits(recharge_limit, 0.65)
                hdr << [mys.subscription_id, my_title, price, my_update_sub.parsed_response['subscription']]
            
            end

            end
            #CSV above


          end 

          def fix_multiple_subs
            #Fix multiple subs for the customer.
            puts "Hi ... starting"
            num_multiple = 0
            MultipleFixPriceSub.delete_all
            ActiveRecord::Base.connection.reset_pk_sequence!('multiple_fix_price_subs')

            CSV.foreach('gabby_csv_input.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
                #puts row.inspect
                customer_id = row['customer_id']
                puts customer_id
                my_sub = Subscription.where("product_title ilike \'%3%item%\' and customer_id = ? and created_at < ? and is_prepaid = ?", customer_id, '2019-08-01', false)
                puts "my_sub = #{my_sub.inspect}"
                puts "count of subs = #{my_sub.count}"
                if my_sub.count > 1
                    num_multiple += 1
                    my_sub.each do |mys|
                        puts "******************"
                        puts mys.inspect
                        puts "******************"
                        temp_sub = mys
                        MultipleFixPriceSub.create(subscription_id: temp_sub.subscription_id, address_id: temp_sub.address_id, customer_id: temp_sub.customer_id, created_at: temp_sub.created_at, updated_at: temp_sub.updated_at, next_charge_scheduled_at: temp_sub.next_charge_scheduled_at, cancelled_at: temp_sub.cancelled_at,  product_title: temp_sub.product_title, price: temp_sub.price, quantity: temp_sub.quantity, status: temp_sub.status, shopify_product_id: temp_sub.shopify_product_id, shopify_variant_id: temp_sub.shopify_variant_id, sku: temp_sub.sku,  order_interval_unit: temp_sub. order_interval_unit, order_interval_frequency: temp_sub.order_interval_frequency, charge_interval_frequency: temp_sub.charge_interval_frequency, order_day_of_month: temp_sub.order_day_of_month, order_day_of_week: temp_sub.order_day_of_week, raw_line_item_properties: temp_sub.raw_line_item_properties, expire_after_specific_number_charges: temp_sub.expire_after_specific_number_charges, is_prepaid: temp_sub.is_prepaid)
                    end
                end


            end

            puts "We have #{num_multiple} subs"

          end


          def filter_out_already_processed
            puts "Starting filter out"

            mysql = "select subscription_id from multiple_fix_price_subs where subscription_id in (select subscription_id from fix_prices_subs)"
            array_to_delete = Array.new

            subscription_id_to_remove = ActiveRecord::Base.connection.execute(mysql).values.flatten
            puts subscription_id_to_remove.inspect
            subscription_id_to_remove.each do |sub_id|
                puts "subscription_id = #{sub_id}"
                my_sub = MultipleFixPriceSub.find_by_subscription_id(sub_id)
                puts "ID for sub = #{my_sub.id}"
                array_to_delete.push(my_sub.id)
                


            end
            puts "Deleting ..."
            MultipleFixPriceSub.delete(array_to_delete)


          end


          def fix_multiple_subs_recharge_after_filter
            puts "Starting"
            my_subs_to_update = MultipleFixPriceSub.where("updated = \'f\' ")

            my_subs_to_update.each do |mys|

                my_now = DateTime.now
                body = { "price" => @price_should_be}.to_json
                
                my_update_sub = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{mys.subscription_id}", :headers => @my_change_header, :body => body, :timeout => 80)
                puts my_update_sub.inspect
                recharge_limit = my_update_sub.response["x-recharge-limit"]
                determine_limits(recharge_limit, 0.65)
                if my_update_sub.code == 200
                    mys.updated = true
                    mys.date_price_updated_at = my_now
                    mys.save!

                else
                    puts "Could not process the subscription id = #{mys.subscription_id}"
                end
               

            end


          end


          def determine_limits(recharge_header, limit)
            puts "recharge_header = #{recharge_header}"
            my_numbers = recharge_header.split("/")
            my_numerator = my_numbers[0].to_f
            my_denominator = my_numbers[1].to_f
            my_limits = (my_numerator/ my_denominator)
            puts "We are using #{my_limits} % of our API calls"
            if my_limits > limit
                puts "Sleeping 15 seconds"
                sleep 15
            else
                puts "not sleeping at all"
            end
      
          end



    end
end