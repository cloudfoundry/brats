require_relative '../spec_helper'

FIXTURE_DIR  = "#{File.dirname(__FILE__)}/../fixtures/nodejs/simple_brats"
PACKAGE_JSON = "#{FIXTURE_DIR}/package.json"

RSpec.shared_examples :a_deploy_of_nodejs_app_to_cf do |node_version|

  context "with node-#{node_version}" do

    before :all do
      create_package_json(node_version)
      @app     = Machete.deploy_app('nodejs/simple_brats', buildpack: 'nodejs-brat-buildpack')
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
      expect(@app).to have_logged("Downloading and installing node #{node_version}")
    end

    it 'should not have internet traffic with a cached buildpack' do
      expect(@app.host).not_to have_internet_traffic if Machete::BuildpackMode.offline?
    end

    after :all do
      FileUtils.rm PACKAGE_JSON
    end
  end
end

describe 'Deploying CF apps' do

  nodes = YAML.load(
    open('https://raw.githubusercontent.com/cloudfoundry/nodejs-buildpack/master/manifest.yml').read
  )['dependencies'].select { |node|
    node['name'] == 'node'
  }

  ['lucid64', 'cflinuxfs2'].each do |stack|
    context "on the #{stack} stack" do

      before :all do
        ENV['CF_STACK'] = stack
      end

      nodes.select { |node|
        node['cf_stacks'].include?(stack)
      }.each do |node|

        it_behaves_like :a_deploy_of_nodejs_app_to_cf, node['version']
      end
    end
  end

end

def create_package_json(node_engine)
  package = {
    'name' => 'node_web_app',
    'version' => '0.0.0',
    'description' => 'hello, world',
    'main' => 'server.js',
    'engines' => {
      'node' => node_engine
    }
  }

  File.open(PACKAGE_JSON, 'w') do |file|
    file << JSON.generate(package)
  end
end
