require 'spec_helper'

RSpec.shared_examples :a_deploy_of_nodejs_app_with_version_range do |node_version, stack|
  context "with node-#{node_version}", version: node_version do
    before :all do
      template = NodeJSTemplateApp.new(node_version)
      template.generate!

      @app = Machete.deploy_app(
        template.path,
        name: template.name,
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

    it 'should have the correct version' do
      expect(@app).to_not have_logged /Downloading and installing undefined.../
      expect(@app).to have_logged "engines.node (package.json):  #{node_version}"
      expect(@app).to have_logged /Downloading and installing node \d+\.\d+\.\d+/
    end

    after :all do
      Machete::CF::DeleteApp.new.execute(@app)
    end
  end
end

RSpec.shared_examples :a_deploy_of_nodejs_app_to_cf do |node_version, stack|
  context "with node-#{node_version}", version: node_version do
    before :all do
      template = NodeJSTemplateApp.new(node_version)
      template.generate!

      @app = Machete.deploy_app(
        template.path,
        name: template.name,
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

    # bson-ext does not support the v8 engine and hence node 6
    # context: https://github.com/christkv/bson-ext/issues/28#issuecomment-212258411
    unless /6\.\d+\.\d+/ =~ node_version
      it 'supports bson-ext' do
        expect(@app).to be_running
        2.times do
          @browser.visit_path('/bson-ext')
          expect(@browser).to have_body('Hello Bson-ext!')
        end
      end
    end

    it 'should have the correct version' do
      expect(@app).to have_logged("Downloading and installing node #{node_version}")
    end

    after :all do
      Machete::CF::DeleteApp.new.execute(@app)
    end
  end
end

describe 'Deploying CF apps', language: 'nodejs' do
  before(:all) { install_buildpack(buildpack: 'nodejs') }
  after(:all) { cleanup_buildpack(buildpack: 'nodejs') }

  def self.nodes
    parsed_manifest(buildpack: 'nodejs')
      .fetch('dependencies')
      .select { |d| d['name'] == 'node' }
  end

  ['cflinuxfs2'].each do |stack|
    context "on the #{stack} stack", stack: stack do
      all_versions = nodes.select { |node|
        node['cf_stacks'].include?(stack) &&
        Gem::Version.new(node['version']) >= Gem::Version.new('0.10')
      }
      all_versions.each do |node|
        it_behaves_like :a_deploy_of_nodejs_app_to_cf, node['version'], stack
      end

      all_versions.map { |node|
        version = node['version']
        '~>' + /(\d+)\.(\d+)/.match(version)[0] + '.0'
      }.uniq.each do |squiggle_version|
        it_behaves_like :a_deploy_of_nodejs_app_with_version_range, squiggle_version, stack
      end
    end
  end
end
