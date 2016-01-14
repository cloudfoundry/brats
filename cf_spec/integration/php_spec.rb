require 'spec_helper'
require 'pry'

RSpec.shared_examples :a_deploy_of_php_app_to_cf do |runtime_version, web_server_binary, stack|
  web_server         = web_server_binary['name']
  web_server_version = web_server_binary['version']

  context "with php-#{runtime_version} and web_server: #{web_server}-#{web_server_version}", version: runtime_version do
    before :all do
      template = PHPTemplateApp.new(
        runtime_version: runtime_version,
        web_server: web_server,
        web_server_version: web_server_version
      )
      template.generate!

      @options = template.options

      @app = Machete.deploy_app(
        template.path,
        name: template.name,
        buildpack: 'php-brat-buildpack',
        stack: stack
      )
      @browser = Machete::Browser.new(@app)
    end

    it 'should be running' do
      expect(@app).to be_running
      2.times do
        @browser.visit_path('/')
        expect(@browser).to have_body('Hello World!')
      end
    end

    it 'should have the correct version' do
      expect(@app).to have_logged('Installing PHP')
      expect(@app).to have_logged("PHP #{runtime_version}")
    end

    it 'should load all of the modules specified in options.json' do
      @browser.visit_path("/?#{@options['PHP_EXTENSIONS'].join(',')}")
      @options['PHP_EXTENSIONS'].each do |extension|
        expect(@browser).to have_body("SUCCESS: #{extension} loads")
      end
    end

    it 'should not include any warning messages when loading all the extensions' do
      expect(@app).to_not have_logged(/The extension .* is not provided by this buildpack./)
    end

    it 'should not load unknown module' do
      @browser.visit_path('/?something')
      expect(@browser).to have_body('ERROR: something failed to load.')
    end

    after :all do
      Machete::CF::DeleteApp.new.execute(@app)
    end
  end
end

describe 'Deploying CF apps', language: 'php' do
  before(:all) { install_buildpack(buildpack: 'php') }
  after(:all) { cleanup_buildpack(buildpack: 'php') }

  def self.dependencies
    parsed_manifest(buildpack: 'php')
      .fetch('dependencies')
  end

  php_runtimes       = dependencies.select { |binary| binary['name'] == 'php' }

  valid_web_servers  = %w(httpd nginx)
  web_servers        = dependencies.select { |binary| valid_web_servers.include?(binary['name']) }

  ['cflinuxfs2'].each do |stack|
    context "on the #{stack} stack", stack: stack do
      php_runtimes.select { |php_runtime|
        php_runtime['cf_stacks'].include?(stack)
      }.each do |php_runtime|
        web_servers.select {|web_server|
          web_server['cf_stacks'].include?(stack)
        }.each do |web_server|
          it_behaves_like :a_deploy_of_php_app_to_cf, php_runtime['version'], web_server, stack
        end
      end
    end
  end
end
