collection @variants
attributes :id, :name, :count_on_hand, :sku, :price, :weight, :height, :width, :depth, :is_master, :cost_price
child(:option_values) do
  attributes :name, :presentation, :option_type_name, :option_type_id
end
