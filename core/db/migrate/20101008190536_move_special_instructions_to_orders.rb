class MoveSpecialInstructionsToOrders < ActiveRecord::Migration
  def self.up
    add_column :orders, :special_instructions, :text

    ActiveRecord::Base.connection.execute('UPDATE orders SET special_instructions = (SELECT special_instructions FROM checkouts WHERE order_id = orders.id)')
  end

  def self.down
    remove_column :orders, :special_instructions, :text
  end
end
