module Spree
  class ProductsController < Spree::StoreController
    before_action :load_product, only: :show
    before_action :load_taxon, only: :index

    rescue_from ActiveRecord::RecordNotFound, with: :render_404
    helper 'spree/taxons'

    respond_to :html

    def index
      @searcher = build_searcher(params.merge(include_images: true))
      @products = @searcher.retrieve_products.send(sorting_param)
      @taxonomies = Spree::Taxonomy.includes(root: :children)
    end

    def show
      @variants = @product.
        variants_including_master.
        display_includes.
        with_prices(current_pricing_options).
        includes([:option_values, :images])

      @product_properties = @product.product_properties.includes(:property)
      @taxon = Spree::Taxon.find(params[:taxon_id]) if params[:taxon_id]
    end

    private

    def sorting_param
      params[:sort_by].try(:to_sym) || default_sorting
    end

    def sorting_scope
      allowed_sortings.include?(sorting_param) ? sorting_param : default_sorting
    end

    def default_sorting
      :ascend_by_created_at
    end

    def allowed_sortings
      [:ascend_by_created_at, :descend_by_created_at, :ascend_by_name, :descend_by_name]
    end

    def accurate_title
      if @product
        @product.meta_title.blank? ? @product.name : @product.meta_title
      else
        super
      end
    end

    def load_product
      if try_spree_current_user.try(:has_spree_role?, "admin")
        @products = Spree::Product.with_deleted
      else
        @products = Spree::Product.available
      end
      @product = @products.friendly.find(params[:id])
    end

    def load_taxon
      @taxon = Spree::Taxon.find(params[:taxon]) if params[:taxon].present?
    end
  end
end
