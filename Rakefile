require 'redis'
require 'resque'
Resque.redis = Redis.new(url: ENV['REDIS_URL'])
require 'active_record'
#require 'sinatra'
require 'sinatra/activerecord/rake'
require 'resque/tasks'
require_relative 'fix_prices'

#require 'pry'

namespace :fix_prices do 
desc 'input three item customers to find matching subs'
task :input_three_items do |t|
    FixPrices::ThreeItems.new.input_three_items

end

desc 'check to see if price needs updating'
task :check_for_price_updating do |t|
    FixPrices::ThreeItems.new.check_for_current_recharge_price
end

desc 'test update one sub with new price'
task :test_update, :sub_id do |t, args|
    sub_id = args['sub_id']
    FixPrices::ThreeItems.new.update_one_sub_recharge(sub_id)

end

desc 'update subs prices on Recharge with new price'
task :update_subs_prices_on_recharge do |t|
    FixPrices::ThreeItems.new.update_subs_on_recharge
end


end