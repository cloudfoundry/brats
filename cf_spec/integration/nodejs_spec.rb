require 'spec_helper'

def generate_nodejs_app(nodejs_version)
  template = NodeJSTemplateApp.new(nodejs_version)
  template.generate!
  template
end

RSpec.shared_examples :a_deploy_of_nodejs_app_with_version_range do |nodejs_version, stack|
  context "with node #{nodejs_version}" do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      app_template = generate_nodejs_app(nodejs_version)
      @app = deploy_app(template: app_template, stack: stack, buildpack: 'nodejs-brat-buildpack')
    end

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
      expect(@app).to have_logged "engines.node (package.json):  #{nodejs_version}"
      expect(@app).to have_logged /Downloading and installing node \d+\.\d+\.\d+/
    end
  end
end

RSpec.shared_examples :a_deploy_of_nodejs_app_to_cf do |nodejs_version, stack|
  context "with node #{nodejs_version}", version: nodejs_version do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      app_template = generate_nodejs_app(nodejs_version)
      @app = deploy_app(template: app_template, stack: stack, buildpack: 'nodejs-brat-buildpack')
    end

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
    unless /6\.\d+\.\d+/ =~ nodejs_version
      it 'supports bson-ext' do
        expect(@app).to be_running
        2.times do
          browser.visit_path('/bson-ext')
          expect(browser).to have_body('Hello Bson-ext!')
        end
      end
    end

    it 'should have the correct version' do
      expect(@app).to have_logged("Downloading and installing node #{nodejs_version}")
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

        nodejs_versions = dependency_versions_in_manifest('nodejs', 'node', stack)

        nodejs_versions.each do |nodejs_version|
          it_behaves_like :a_deploy_of_nodejs_app_to_cf, nodejs_version, stack
        end

        nodejs_versions.map { |nodejs_version|
          '~>' + /(\d+)\.(\d+)/.match(nodejs_version)[0] + '.0'
        }.uniq.each do |squiggle_version|
          it_behaves_like :a_deploy_of_nodejs_app_with_version_range, squiggle_version, stack
        end
      end
    end
  end

  describe 'staging with custom buildpack that uses credentials in manifest dependency uris' do
    let(:stack)          { 'cflinuxfs2' }
    let(:nodejs_version) { dependency_versions_in_manifest('nodejs', 'node', stack).last }
    let(:app) do
      app_template = generate_nodejs_app(nodejs_version)
      deploy_app(template: app_template, stack: stack, buildpack: 'nodejs-brat-buildpack')
    end

    before do
      cleanup_buildpack(buildpack: 'nodejs')
      install_buildpack_with_uri_credentials(buildpack: 'nodejs', buildpack_caching: caching)
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    context "using an uncached buildpack" do
      let(:caching)        { :uncached }
      let(:credential_uri) { Regexp.new(Regexp.quote('https://') + 'login:password[@]') }
      let(:node_uri)       { Regexp.new(Regexp.quote('https://-redacted-:-redacted-@buildpacks.cloudfoundry.org/concourse-binaries/node/node-') + '[\d\.]+' + Regexp.quote('-linux-x64.tgz')) }

      it 'does not include credentials in logged dependency uris' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to have_logged(node_uri)
      end
    end

    context "using a cached buildpack" do
      let(:caching)        { :cached }
      let(:credential_uri) { Regexp.new('https___login_password') }
      let(:node_uri)       { Regexp.new(Regexp.quote('https___-redacted-_-redacted-@buildpacks.cloudfoundry.org_concourse-binaries_node_node-') + '[\d\.]+' + Regexp.quote('-linux-x64.tgz')) }

      it 'does not include credentials in logged dependency file paths' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to have_logged(node_uri)
      end
    end
  end

  describe 'deploying an app that has an executable .profile script' do
    let(:stack)          { 'cflinuxfs2' }
    let(:nodejs_version) { dependency_versions_in_manifest('nodejs', 'node', stack).last }
    let(:app) do
      app_template = generate_nodejs_app(nodejs_version)
      add_dot_profile_script_to_app(app_template.full_path)
      deploy_app(template: app_template, stack: stack, buildpack: 'nodejs-brat-buildpack')
    end
    let(:browser) { Machete::Browser.new(app) }

    before(:all) do
      skip_if_no_dot_profile_support_on_targeted_cf
      cleanup_buildpack(buildpack: 'nodejs')
      install_buildpack(buildpack: 'nodejs')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'executes the .profile script' do
      expect(app).to have_logged("PROFILE_SCRIPT_IS_PRESENT_AND_RAN")
    end

    it 'does not let me view the .profile script' do
      browser.visit_path('/.profile')
      expect(browser.status).to eq(404)
    end
  end
end
