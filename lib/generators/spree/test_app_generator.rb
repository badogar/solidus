require 'rails/generators'

module Spree
  module Generators
    class TestAppGenerator < Rails::Generators::Base

      class << self
        attr_accessor :verbose
      end

      class_option :app_name, :type => :string,
                              :desc => "The name of the test rails app to generate. Defaults to test_app.",
                              :default => "test_app"

      def self.source_root
        File.expand_path('../../templates', __FILE__)
      end

      def generate_app
          remove_directory_if_exists("spec/#{test_app}")
          inside "spec" do
            run "rails new #{test_app} --database=#{database_name} -GJTq --skip-gemfile"
          end
      end

      def create_rspec_gemfile
        # newer versions of rspec require a Gemfile in the local gem dirs so create one there as well as in spec/test_app
        silence_stream(STDOUT) {
          template "Gemfile.#{database_name}", :force => true
          mv "Gemfile.#{database_name}", "Gemfile", :verbose => false
          remove_file "Gemfile.lock"
        }
      end

      def create_root
        self.destination_root = File.expand_path("spec/#{test_app}", destination_root)
      end

      def remove_unneeded_files
        silence_stream(STDOUT) {
          remove_file "doc"
          remove_file "lib/tasks"
          remove_file "public/images/rails.png"
          remove_file "public/index.html"
          remove_file "README"
          remove_file "vendor"
        }
      end

      def replace_gemfile
        silence_stream(STDOUT) {
          template "Gemfile.#{database_name}"
          mv "spec/test_app/Gemfile.#{database_name}", "spec/test_app/Gemfile", :verbose => false
        }
      end

      def setup_environments
        silence_stream(STDOUT) {
          template "config/environments/cucumber.rb"
        }
      end

      def create_databases_yml
        silence_stream(STDOUT) {
          remove_file "config/database.yml"
          template "config/database.yml.#{database_name}"
          mv "spec/test_app/config/database.yml.#{database_name}", "spec/test_app/config/database.yml", :verbose => false
        }
      end

      def tweak_gemfile
        silence_stream(STDOUT) {
          append_file '../../Gemfile' do
            full_path_for_local_gems
          end

          append_file 'Gemfile' do
            full_path_for_local_gems
          end
        }
      end

      protected
      def full_path_for_local_gems
        # Gemfile needs to be full local path to the source (ex. /Users/schof/repos/spree/auth)
        # By default we do nothing but each gem should override this method with the appropriate content
      end

      private

      def run_migrations
        silence_stream(STDOUT) {
          inside "" do
              run "rake db:drop db:create db:migrate db:seed RAILS_ENV=test"
              run "rake db:drop db:create db:migrate db:seed RAILS_ENV=cucumber"
          end
        }
      end

      def test_app
        options[:app_name]
      end

      def database_name
        # By default nothing is done here but each gem should override this method with the appropriate content
      end

      def remove_directory_if_exists(path)
        silence_stream(STDOUT) {
          run "rm -r #{path}" if File.directory?(path)
        }
      end

      def silence_stream(stream)
        if self.class.verbose
          yield
        else
          begin
            old_stream = stream.dup
            stream.reopen(RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ? 'NUL:' : '/dev/null')
            stream.sync = true
            yield
          ensure
            stream.reopen(old_stream)
          end
        end
      end
    end
  end
end