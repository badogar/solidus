object false
child(@properties => :properties) do
  attributes *property_attributes
end
node(:count) { @properties.count }
node(:current_page) { params[:page] || 1 }
node(:pages) { @properties.total_pages }
