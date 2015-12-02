require 'spec_helper'

module Hhvm
  FIXTURE_DIR = "#{File.dirname(__FILE__)}/../fixtures/php/simple_brats"
  OPTIONS_JSON = "#{FIXTURE_DIR}/.bp-config/options.json"

  def self.create_options_json(options = {})
    runtime_version    = options[:runtime_version]
    web_server         = options[:web_server]
    web_server_version = options[:web_server_version]

    options = {
      'PHP_VM' => 'hhvm',
      "HHVM_VERSION" => runtime_version,
      'WEB_SERVER' => web_server,
      "#{web_server.upcase}_VERSION" => web_server_version
    }

    File.open(OPTIONS_JSON, 'w') do |file|
      file << JSON.generate(options)
    end
  end
end

RSpec.shared_examples :a_deploy_of_hhvm_app_to_cf do |runtime_version, web_server_binary, stack|

  web_server         = web_server_binary['name']
  web_server_version = web_server_binary['version']

  context "with hhvm-#{runtime_version} and web_server: #{web_server}-#{web_server_version}", version: runtime_version do

    before :all do
      Hhvm::create_options_json({
        :runtime_version    => runtime_version,
        :web_server         => web_server,
        :web_server_version => web_server_version
      })
      @app = Machete.deploy_app(
        'php/simple_brats',
        name: "simple-php-#{Time.now.to_i}",
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
      expect(@app).to have_logged("Installing HHVM")
      expect(@app).to have_logged("HHVM #{runtime_version}")
    end

    after :all do
      Machete::CF::DeleteApp.new.execute(@app)
      FileUtils.rm Hhvm::OPTIONS_JSON
    end
  end
end

describe 'Deploying CF apps', :language => 'php' do
  before(:all) { install_buildpack(buildpack: 'php') }
  after(:all) { cleanup_buildpack(buildpack: 'php') }

  def self.dependencies
    parsed_manifest(buildpack: 'php')
      .fetch('dependencies')
  end

  hhvm_runtimes      = dependencies.select {|binary| binary['name'] == 'hhvm' }

  valid_web_servers  = ['httpd', 'nginx']
  web_servers        = dependencies.select {|binary| valid_web_servers.include?(binary['name']) }

  ['cflinuxfs2'].each do |stack|
    context "on the #{stack} stack", stack: stack do

      hhvm_runtimes.select { |hhvm_runtime|
        hhvm_runtime['cf_stacks'].include?(stack)
      }.each do |hhvm_runtime|

        web_servers.select {|web_server|
          web_server['cf_stacks'].include?(stack)
        }.each do |web_server|

          it_behaves_like :a_deploy_of_hhvm_app_to_cf, hhvm_runtime['version'], web_server, stack
        end
      end
    end
  end
end


