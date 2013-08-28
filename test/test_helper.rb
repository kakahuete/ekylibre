# -*- coding: utf-8 -*-
require 'coveralls'
Coveralls.wear!('rails')

ENV["RAILS_ENV"] ||= "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
# require 'rspec/rails'
# require 'rspec/autorun'
require 'capybara/rails'
# require 'capybara/rspec'
# require 'capybara-screenshot/rspec'


# Removes use of shoulda gem until bug is not fixed for Rails >= 1.9.3
# Use specific file lib/shoulda/context/context.rb
# TODO: Re-add shoulda-context in Gemfile ASAP
# require File.join(File.dirname(__FILE__), 'shoulda-context')
# class ActiveSupport::TestCase
#   include Shoulda::Context::InstanceMethods
#   extend Shoulda::Context::ClassMethods
# end


# Choix du driver par défaut : selenium pour le Javascript
#
Capybara.default_driver = :selenium
Capybara.default_wait_time = 5
#Capybara.default_driver = :webkit

class CapybaraIntegrationTest < ActionDispatch::IntegrationTest
  include Capybara::DSL
  include Capybara::Screenshot
  include Warden::Test::Helpers
  Warden.test_mode!

  def shoot_screen(name)
    file = Rails.root.join("tmp", "screenshots", name + ".png")
    FileUtils.mkdir_p(file.dirname) unless file.dirname.exist?
    save_screenshot file
  end

  #add a method to test unroll in form
  #FIXME : add an AJAX helpers to capybara for testing unroll field
    # http://stackoverflow.com/questions/13187753/rails3-jquery-autocomplete-how-to-test-with-rspec-and-capybara/13213185#13213185
    # http://jackhq.tumblr.com/post/3728330919/testing-jquery-autocomplete-using-capybara
  def fill_unroll(field, options = {})
    fill_in field, :with => options[:with]
    sleep(1)
    #page.execute_script %Q{ $('##{field}').trigger("focus") }
    #page.execute_script %Q{ $('##{field}').trigger("keydown") }
    selector = "input##{field} + .items-menu .items-list .item[data-item-label=\"#{options[:select]}\"]"
    #page.should have_xpath(selector)
    page.execute_script "$('#{selector}').trigger('mouseenter').click();"
  end

end



class ActiveSupport::TestCase
  ActiveRecord::Migration.check_pending!

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...

  def actions_of(cont)
    User.rights[cont].keys
  end

  # def login(name, password)
  #   # print "L"
  #   old_controller = @controller
  #   @controller = SessionsController.new
  #   post :create, :name => name, :password => password
  #   assert_response :redirect
  #   assert_redirected_to root_url, "If login succeed, a redirection must be done to #{root_url}"
  #   assert_not_nil(session[:user_id])
  #   @controller = old_controller
  # end

  def fast_login(entity)
    # print "V"
    @controller.send(:init_session, entity)
  end


end



class ActionController::TestCase
  include Devise::TestHelpers

  def self.test_restfully_all_actions(options={})
    controller ||= self.controller_class.to_s[0..-11].underscore.to_sym
    code  = ""
    code << "context 'A #{controller} controller' do\n"
    code << "\n"
    code << "  setup do\n"
    # force locale
    code << "    I18n.locale = I18n.default_locale\n"
    code << "    assert_not_nil I18n.locale\n"
    code << "    assert_equal I18n.locale, I18n.locale, I18n.locale.inspect\n"
    code << "    @user = users(:users_001)\n"
    # code << "    login('gendo', 'secret')\n"
    code << "    sign_in(@user)\n"
    code << "    CustomField.all.each(&:save)\n"
    code << "  end\n"
    # code << "  teardown do\n"
    # code << "    @user = nil\n"
    # code << "    reset_session\n"
    # code << "  end\n"

    except = options.delete(:except)||[]
    except = [except] unless except.is_a? Array
    return unless User.rights[controller]
    for action in User.rights[controller].keys.sort{|a,b| a.to_s <=> b.to_s} # .delete_if{|x| ![:index, :new, :create, :edit, :update, :destroy, :show].include?(x.to_sym)} # .delete_if{|x| except.include? x}
      action = action.to_sym
      if except.include? action
        puts "Ignore: #{controller}##{action}"
        next
      end

      code << "\n"
      code << "  should \"#{action}\" do\n"

      unless mode = options[action] and options[action].is_a? Symbol
        action_name = action.to_s
        mode = if action_name.match(/^(index|new)$/) # GET without ID
                 :index
               elsif action_name.match(/^(show|edit|picture)$/) # GET with ID
                 :show
               elsif action_name.match(/^(create|load)$/) # POST without ID
                 :create
               elsif action_name.match(/^(update)$/) # PUT with ID
                 :update
               elsif action_name.match(/^(destroy)$/) # DELETE with ID
                 :destroy
               elsif action_name.match(/^list(_\w+)?$/) # GET list
                 :list
               elsif action_name.match(/^(duplicate|up|down|lock|unlock|increment|decrement|propose|confirm|refuse|invoice|abort|correct|finish|propose_and_invoice|sort)$/) # POST with ID
                 :touch
               end
      end

      model_name = controller.to_s.split(/\//)[-1].classify
      record = model_name.underscore
      attributes = nil
      model = model_name.constantize rescue nil
      if model
        file_columns = {}
        if model.respond_to?(:attachment_definitions)
          unless model.attachment_definitions.nil?
            file_columns = model.attachment_definitions
          end
        end
        # protected_attributes = model.protected_attributes.to_a - ["id", "type"]
        # attributes = if model.accessible_attributes.to_a.size > 0
        #                restricted = true
        #                model.accessible_attributes.to_a
        #              elsif protected_attributes.size > 0
        #                restricted = true
        #                model.attribute_names - protected_attributes
        #              else
        #                model.attribute_names
        #              end.delete_if{|a| a.blank? or a.to_s.match(/_attributes$/)}
        attributes = model.content_columns.map(&:name)
        attributes = "{" + attributes.collect do |a|
          if file_columns[a.to_sym]
            ":#{a} => fixture_file_upload('files/sample_image.png')"
          else
            ":#{a} => #{record}.#{a}"
          end
        end.join(", ")+ "}"
      end
      table_name = (model ? model.table_name : "unknown_table")
      fixture_name = record.pluralize
      fixture_table = table_name

      if options[action].is_a? Hash
        code << "    get :#{action}, #{options[action].inspect[1..-2]}\n"
        code << "    assert_response :success, \"The action #{action.inspect} does not seem to support GET method \#{redirect_to_url} / \#{flash.inspect}\"\n"
      elsif mode == :index
        code << "    get :#{action}\n"
        code << '    assert_response :success, "Flash: #{flash.inspect}"'+"\n"
      elsif mode == :show
        code << "    assert_nothing_raised do\n"
        code << "      get :#{action}, :id => 'NaID'\n"
        code << "    end\n"
        code << "    #{record} = #{fixture_table}(:#{fixture_name}_001)\n"
        code << "    assert_equal 1, #{model_name}.where(id: #{record}.id).count\n"
        code << "    assert #{record}.valid?, '#{fixture_name}_001 must be valid:' + #{record}.errors.inspect\n"
        code << "    get :#{action}, :id => #{record}.id\n"
        code << "    assert_response :success, \"Flash: \#{flash.inspect}\"\n"
        code << "    assert_not_nil assigns(:#{record})\n"
      elsif mode == :create
        code << "    #{record} = #{fixture_table}(:#{fixture_name}_001)\n"
        code << "    assert #{record}.valid?, '#{fixture_name}_001 must be valid:' + #{record}.errors.inspect\n"
        code << "    post :#{action}, :#{record} => #{attributes}\n"
        # if restricted
        #   code << "    assert_raise(ActiveModel::MassAssignmentSecurity::Error, 'POST #{controller}/#{action}') do\n"
        #   code << "      post :#{action}, :#{record} => #{record}.attributes\n"
        #   code << "    end\n"
        # end
      elsif mode == :update
        code << "    #{record} = #{fixture_table}(:#{fixture_name}_001)\n"
        code << "    assert #{record}.valid?, '#{fixture_name}_001 must be valid:' + #{record}.errors.inspect\n"
        code << "    put :#{action}, :id => #{record}.id, :#{record} => #{attributes}\n"
        # if restricted
        #   code << "    assert_raise(ActiveModel::MassAssignmentSecurity::Error, 'PUT #{controller}/#{action}/:id') do\n"
        #   code << "      put :#{action}, :id => #{record}.id, :#{record} => #{record}.attributes\n"
        #   code << "    end\n"
        # end
      elsif mode == :destroy
        code << "    #{record} = #{fixture_table}(:#{fixture_name}_002)\n"
        code << "    assert_nothing_raised do\n"
        code << "      delete :#{action}, :id => #{record}.id\n"
        code << "    end\n"
        code << "    assert_response :redirect\n"
      elsif mode == :list
        code << "    get :#{action}\n"
        code << "    assert_response :success, \"The action #{action.inspect} does not seem to support GET method \#{redirect_to_url} / \#{flash.inspect}\"\n"
        for format in [:csv, :xcsv, :ods]
          code << "    get :#{action}, :format => :#{format}\n"
          code << "    assert_response :success, 'Action #{action} does not export in format #{format}'\n"
        end
      elsif mode == :touch
        # code << "    assert_raise ActionController::RoutingError, 'POST #{controller}/#{action}' do\n"
        # code << "      post :#{action}\n"
        # code << "    end\n"
        code << "    post :#{action}, :id => 'NaID'\n"
        code << "    #{record} = #{fixture_table}(:#{fixture_name}_001)\n"
        code << "    assert #{record}.valid?, '#{fixture_name}_001 must be valid:' + #{record}.errors.inspect\n"
        code << "    post :#{action}, :id => #{record}.id\n"
        code << "    assert_response :redirect\n"
      elsif mode == :get_and_post # with ID
        # code << "    assert_raise ActionController::RoutingError, 'GET #{controller}/#{action}' do\n"
        # code << "      get :#{action}\n"
        # code << "    end\n"
        code << "    get :#{action}, :id => 'NaID'\n"
        code << "    #{record} = #{fixture_table}(:#{fixture_name}_001)\n"
        code << "    assert #{record}.valid?, '#{fixture_name}_001 must be valid:' + #{record}.errors.inspect\n"
        code << "    get :#{action}, :id => #{record}.id\n"
        code << '    assert_response :success, "Flash: #{flash.inspect}"'+"\n"
      elsif mode == :index_xhr
        code << "    get :#{action}\n"
        code << "    assert_response :redirect\n"
        code << "    xhr :get, :#{action}\n"
        code << '    assert_response :success, "Flash: #{flash.inspect}"'+"\n"
      elsif mode == :show_xhr
        code << "    #{record} = #{fixture_table}(:#{fixture_name}_001)\n"
        code << "    assert #{record}.valid?, '#{fixture_name}_001 must be valid:' + #{record}.errors.inspect\n"
        code << "    get :#{action}, :id => #{record}.id\n"
        code << "    assert_response :redirect\n"
        code << "    xhr :get, :#{action}, :id => #{record}.id\n"
        code << "    assert_not_nil assigns(:#{record})\n"
      else
        code << "    get :#{action}\n"
        code << "    assert_response :success, \"The action #{action.inspect} does not seem to support GET method \#{redirect_to_url} / \#{flash.inspect}\"\n"
        code << "    assert_select('html body div#wrap', 1, 'Cannot get main element in view #{action}')\n" # +response.inspect
      end
      code << "  end\n"
    end
    # code << "  end\n"
    code << "end\n"

    file = Rails.root.join("tmp", "auto-tests", "#{controller}.rb")
    FileUtils.mkdir_p(file.dirname)
    File.open(file, "wb") do |f|
      f.write(code)
    end
    # code.split("\n").each_with_index{|line, x| puts((x+1).to_s.rjust(4)+": "+line)}

    class_eval(code, "#{__FILE__}:#{__LINE__}")

  end
end

