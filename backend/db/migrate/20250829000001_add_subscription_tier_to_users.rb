class AddSubscriptionTierToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :subscription_tier, :string, default: 'standard', null: false
    add_index :users, :subscription_tier
  end
end
