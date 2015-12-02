require 'spec_helper'

module NodeJs
  FIXTURE_DIR  = "#{File.dirname(__FILE__)}/../fixtures/nodejs/simple_brats"
  PACKAGE_JSON = "#{FIXTURE_DIR}/package.json"
end

RSpec.shared_examples :a_deploy_of_nodejs_app_to_cf do |node_version, stack|

  context "with node-#{node_version}", version: node_version do

    def create_package_json(node_engine)
      package = {
        'name' => 'node_web_app',
        'version' => '0.0.0',
        'description' => 'hello, world',
        'main' => 'server.js',
        'engines' => {
          'node' => node_engine
        },
        'dependencies' => {
          'bcrypt' => '0.8.5',
          'bson-ext' => '0.1.13'
        }
      }

      File.open(NodeJs::PACKAGE_JSON, 'w') do |file|
        file << JSON.generate(package)
      end
    end

    before :all do
      create_package_json(node_version)
      @app = Machete.deploy_app(
        'nodejs/simple_brats',
        name: "simple-nodejs-#{Time.now.to_i}",
        buildpack: 'nodejs-brat-buildpack',
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

    it 'supports bcrypt' do
      expect(@app).to be_running
      2.times do
        @browser.visit_path('/bcrypt')
        expect(@browser).to have_body('Hello Bcrypt!')
      end
    end

    it 'supports bson-ext' do
      expect(@app).to be_running
      2.times do
        @browser.visit_path('/bson-ext')
        expect(@browser).to have_body('Hello Bson-ext!')
      end
    end


    it 'should have the correct version' do
      expect(@app).to have_logged("Downloading and installing node #{node_version}")
    end

    after :all do
      Machete::CF::DeleteApp.new.execute(@app)
      FileUtils.rm NodeJs::PACKAGE_JSON
    end
  end
end

describe 'Deploying CF apps',:language=> 'nodejs' do
  before(:all) { install_buildpack(buildpack: 'nodejs') }
  after(:all) { cleanup_buildpack(buildpack: 'nodejs') }

  def self.nodes
    parsed_manifest(buildpack: 'nodejs')
      .fetch('dependencies')
      .select{|d| d['name'] == 'node'}
  end

  ['cflinuxfs2'].each do |stack|
    context "on the #{stack} stack", stack: stack do

      nodes.select { |node|
        node['cf_stacks'].include?(stack) &&
          Gem::Version.new(node['version']) >= Gem::Version.new('0.10')
      }.each do |node|

        it_behaves_like :a_deploy_of_nodejs_app_to_cf, node['version'], stack
      end
    end
  end

end

