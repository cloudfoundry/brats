require 'spec_helper'

def deploy_nodejs_app(node_version, stack)
  template = NodeJSTemplateApp.new(node_version)
  template.generate!
  Machete.deploy_app(
    template.path,
    name: template.name,
    buildpack: 'nodejs-brat-buildpack',
    stack: stack
  )
end

RSpec.shared_examples :a_deploy_of_nodejs_app_with_version_range do |node_version, stack|
  context "with node #{node_version}" do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) { @app = deploy_nodejs_app(node_version, stack) }

    after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

    it 'should be running' do
      expect(@app).to be_running
      2.times do
        browser.visit_path('/')
        expect(browser).to have_body('Hello World!')
      end
    end

    it 'should have the correct version' do
      expect(@app).to_not have_logged /Downloading and installing undefined.../
      expect(@app).to have_logged "engines.node (package.json):  #{node_version}"
      expect(@app).to have_logged /Downloading and installing node \d+\.\d+\.\d+/
    end
  end
end

RSpec.shared_examples :a_deploy_of_nodejs_app_to_cf do |node_version, stack|
  context "with node #{node_version}", version: node_version do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) { @app = deploy_nodejs_app(node_version, stack) }

    after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

    it 'should be running' do
      expect(@app).to be_running
      2.times do
        browser.visit_path('/')
        expect(browser).to have_body('Hello World!')
      end
    end

    it 'supports bcrypt' do
      expect(@app).to be_running
      2.times do
        browser.visit_path('/bcrypt')
        expect(browser).to have_body('Hello Bcrypt!')
      end
    end

    # bson-ext does not support the v8 engine and hence node 6
    # context: https://github.com/christkv/bson-ext/issues/28#issuecomment-212258411
    unless /6\.\d+\.\d+/ =~ node_version
      it 'supports bson-ext' do
        expect(@app).to be_running
        2.times do
          browser.visit_path('/bson-ext')
          expect(browser).to have_body('Hello Bson-ext!')
        end
      end
    end

    it 'should have the correct version' do
      expect(@app).to have_logged("Downloading and installing node #{node_version}")
    end
  end
end

describe 'For the nodejs buildpack', language: 'nodejs' do
  describe 'Deploying CF apps' do
    before(:all) do
      cleanup_buildpack(buildpack: 'nodejs')
      install_buildpack(buildpack: 'nodejs')
    end

    ['cflinuxfs2'].each do |stack|
      context "on the #{stack} stack", stack: stack do

        node_versions = dependency_versions_in_manifest('nodejs', 'node', stack)

        node_versions.each do |node_version|
          it_behaves_like :a_deploy_of_nodejs_app_to_cf, node_version, stack
        end

        node_versions.map { |node_version|
          '~>' + /(\d+)\.(\d+)/.match(node_version)[0] + '.0'
        }.uniq.each do |squiggle_version|
          it_behaves_like :a_deploy_of_nodejs_app_with_version_range, squiggle_version, stack
        end
      end
    end
  end

  describe 'staging with custom buildpack that uses credentials in manifest dependency uris' do
    let(:stack)        { 'cflinuxfs2' }
    let(:node_version) { dependency_versions_in_manifest('nodejs', 'node', stack).last }
    let(:app)          { deploy_nodejs_app(node_version, stack) }

    before do
      cleanup_buildpack(buildpack: 'nodejs')
      install_buildpack_with_uri_credentials(buildpack: 'nodejs')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'does not include credentials in logged dependency uris' do
      credential_uri = Regexp.new(Regexp.quote('https://') + 'login:password[@]')
      node_uri = Regexp.new(Regexp.quote('https://-redacted-:-redacted-@buildpacks.cloudfoundry.org/concourse-binaries/node/node-') + '[\d\.]+' + Regexp.quote('-linux-x64.tgz'))

      expect(app).to_not have_logged(credential_uri)
      expect(app).to have_logged(node_uri)
    end
  end
end
