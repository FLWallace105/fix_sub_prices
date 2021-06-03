class CreateFixPricesSubs < ActiveRecord::Migration[6.1]
  def change
    create_table :fix_prices_subs do |t|
      t.string :subscription_id
      t.string :address_id
      t.string :customer_id
      t.datetime :created_at
      t.datetime :updated_at
      t.datetime :next_charge_scheduled_at
      t.datetime :cancelled_at
      t.string :product_title
      t.decimal :price, precision: 10, scale: 2
      t.integer :quantity
      t.string :status
      t.string :shopify_product_id
      t.string :shopify_variant_id
      t.string :sku
      t.string :order_interval_unit
      t.integer :order_interval_frequency
      t.integer :charge_interval_frequency
      t.integer :order_day_of_month
      t.integer :order_day_of_week
      t.jsonb :raw_line_item_properties
      t.integer :expire_after_specific_number_charges
      t.boolean :is_prepaid, default: false
      t.decimal :price_on_recharge, precision: 10, scale: 2
      t.boolean :price_checked_on_recharge, default: false
      t.boolean :not_found, default:false
      t.boolean :needs_price_updated, default: false
      t.boolean :updated, default: false
      t.datetime :date_price_updated_at

    end


  end
end
