module Spree
  module Core
    module ControllerHelpers
      def self.included(receiver)
        receiver.send :layout, :get_layout
        receiver.send :before_filter, 'set_user_language'

        receiver.send :helper_method, 'title'
        receiver.send :helper_method, 'title='
        receiver.send :helper_method, 'accurate_title'
        receiver.send :helper_method, 'get_taxonomies'
        receiver.send :helper_method, 'current_order'
        receiver.send :helper_method, 'current_spree_user'
        receiver.send :include, SslRequirement
        receiver.send :include, Spree::Core::CurrentOrder

        receiver.rescue_from CanCan::AccessDenied do |exception|
          return unauthorized
        end
      end

      def access_forbidden
        render :text => 'Access Forbidden', :layout => true, :status => 401
      end

      # can be used in views as well as controllers.
      # e.g. <% title = 'This is a custom title for this view' %>
      attr_writer :title

      def title
        title_string = @title.present? ? @title : accurate_title
        if title_string.present?
          if Spree::Config[:always_put_site_name_in_title]
            [default_title, title_string].join(' - ')
          else
            title_string
          end
        else
          default_title
        end
      end

      def current_spree_user
        if Spree.user_class && Spree.current_user_method
          send(Spree.current_user_method)
        else
          nil
        end
      end

      protected

      # Needs to be overriden so that we use Spree's Ability rather than anyone else's.
      def current_ability
        @current_ability ||= Spree::Ability.new(current_spree_user)
      end

      def store_location
        # disallow return to login, logout, signup pages
        disallowed_urls = [spree_signup_path, spree_login_path, spree_logout_path]
        disallowed_urls.map!{ |url| url[/\/\w+$/] }
        unless disallowed_urls.include?(request.fullpath)
          session['user_return_to'] = request.fullpath.gsub('//', '/')
        end
      end

      # Redirect as appropriate when an access request fails.  The default action is to redirect to the login screen.
      # Override this method in your controllers if you want to have special behavior in case the user is not authorized
      # to access the requested action.  For example, a popup window might simply close itself.
      def unauthorized
        respond_to do |format|
          format.html do
            if current_spree_user
              flash.now[:error] = t(:authorization_failure)
              render 'spree/shared/unauthorized', :layout => '/spree/layouts/spree_application', :status => 401
            else
              store_location
              redirect_to spree_login_path and return
            end
          end
          format.xml do
            request_http_basic_authentication 'Web Password'
          end
          format.json do
            render :text => "Not Authorized \n", :status => 401
          end
        end
      end

      def default_title
        Spree::Config[:site_name]
      end

      # this is a hook for subclasses to provide title
      def accurate_title
        Spree::Config[:default_seo_title]
      end

      def render_404(exception = nil)
        respond_to do |type|
          type.html { render :status => :not_found, :file    => "#{::Rails.root}/public/404", :formats => [:html], :layout => nil}
          type.all  { render :status => :not_found, :nothing => true }
        end
      end

      # Convenience method for firing instrumentation events with the default payload hash
      def fire_event(name, extra_payload = {})
        ActiveSupport::Notifications.instrument(name, default_notification_payload.merge(extra_payload))
      end

      # Creates the hash that is sent as the payload for all notifications. Specific notifications will
      # add additional keys as appropriate. Override this method if you need additional data when
      # responding to a notification
      def default_notification_payload
        {:user => current_spree_user, :order => current_order}
      end

      private

      def redirect_back_or_default(default)
        redirect_to(session["user_return_to"] || default)
        session["user_return_to"] = nil
      end

      def get_taxonomies
        @taxonomies ||= Taxonomy.includes(:root => :children).joins(:root)
      end

      def associate_user
        return unless current_spree_user and current_order
        current_order.associate_user!(current_spree_user)
        session[:guest_token] = nil
      end

      def set_user_language
        locale = session[:locale]
        locale ||= Spree::Config[:default_locale] unless Spree::Config[:default_locale].blank?
        locale ||= Rails.application.config.i18n.default_locale
        locale ||= I18n.default_locale unless I18n.available_locales.include?(locale.to_sym)
        I18n.locale = locale.to_sym
      end

      # Returns which layout to render.
      # 
      # You can set the layout you want to render inside your Spree configuration with the +:layout+ option.
      # 
      # Default layout is: +app/views/spree/layouts/spree_application+
      # 
      def get_layout
        layout ||= Spree::Config[:layout]
      end
    end
  end
end
