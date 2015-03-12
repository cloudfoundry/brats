require_relative '../spec_helper'

FIXTURE_DIR = "#{File.dirname(__FILE__)}/../fixtures/nodejs/simple"
PACKAGE_JSON = "#{FIXTURE_DIR}/package.json"
STACK = ENV['CF_STACK']

describe 'Deploying CF apps' do
  context "on Stack: #{STACK}" do

    YAML.load(
      open('https://raw.githubusercontent.com/cloudfoundry/nodejs-buildpack/master/manifest.yml').read
    )['dependencies'].select{ |node|
      node['cf_stacks'].include? STACK
    }.select { |node|
      node['name'] == 'node'
    }.each do |node|
      version = node['version']

      describe "with node-#{version}" do

        before :all do
          create_package_json(version)
          @app = Machete.deploy_app('nodejs/simple')
          @browser = Machete::Browser.new(@app)
        end

        it 'should be running' do
          2.times do
            @browser.visit_path('/')
            expect(@browser).to have_body('Hello World!')
          end
        end

        it 'should have the correct version' do
          expect(@app).to have_logged("-----> Resolved node version: #{version}")
        end

        it 'should not have internet traffic with a cached buildpack' do
          expect(@app.host).not_to have_internet_traffic if Machete::BuildpackMode.offline?
        end

        after :all do
          FileUtils.rm PACKAGE_JSON
        end
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
