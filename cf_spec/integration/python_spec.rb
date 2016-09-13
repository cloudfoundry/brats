require 'spec_helper'
require 'bcrypt'

def generate_python_app(python_version)
  template = PythonTemplateApp.new(python_version)
  template.generate!
  template
end

RSpec.shared_examples :a_deploy_of_python_app_to_cf do |python_version, stack|
  context "with Python version #{python_version}" do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      app_template = generate_python_app(python_version)
      @app = deploy_app(template: app_template, stack: stack, buildpack: 'python-brat-buildpack')
    end

    after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

    it 'runs a simple webserver', version: python_version do
      expect(@app).to be_running
      expect(@app).to have_logged /Installing.*python-#{python_version}/

      2.times do
        browser.visit_path('/')
        expect(browser).to have_body('Hello, World')
      end
    end

    it 'encrypts with bcrypt', version: python_version do
      2.times do
        browser.visit_path('/bcrypt')
        crypted_text = BCrypt::Password.new(browser.body)
        expect(crypted_text).to eq 'Hello, bcrypt'
      end
    end

    it 'supports postgres by raising a no connection error', version: python_version do
      2.times do
        browser.visit_path '/pg'
        expect(browser).to have_body 'could not connect to server: No such file or directory'
      end
    end

    it 'supports mysql by raising a no connection error', version: python_version do
      2.times do
        browser.visit_path '/mysql'
        expect(browser).to have_body "Can't connect to local MySQL server through socket '/var/run/mysqld/mysqld.sock'"
      end
    end

    it 'supports loading and running the hiredis lib', version: python_version do
      2.times do
        browser.visit_path('/redis')
        expect(browser).to have_body 'Hello'
      end
    end
  end
end


describe 'For the python buildpack', language: 'python' do
  describe 'For all supported Python versions' do
    before(:all) do
      cleanup_buildpack(buildpack: 'python')
      install_buildpack(buildpack: 'python')
    end

    ['cflinuxfs2'].each do |stack|
      context "on the #{stack} stack", stack: stack do
        python_versions = dependency_versions_in_manifest('python', 'python', stack)
        python_versions.each do |python_version|
          it_behaves_like :a_deploy_of_python_app_to_cf, python_version, stack
        end
      end
    end
  end

  describe 'staging with custom buildpack that uses credentials in manifest dependency uris' do
    let(:stack)          { 'cflinuxfs2' }
    let(:python_version) { dependency_versions_in_manifest('python', 'python', stack).last }
    let(:app) do
      app_template = generate_python_app(python_version)
      deploy_app(template: app_template, stack: stack, buildpack: 'python-brat-buildpack')
    end

    before do
      cleanup_buildpack(buildpack: 'python')
      install_buildpack_with_uri_credentials(buildpack: 'python', buildpack_caching: caching)
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    context "using an uncached buildpack" do
      let(:caching)        { :uncached }
      let(:credential_uri) { Regexp.new(Regexp.quote('https://') + 'login:password[@]') }
      let(:python_uri)     { Regexp.new(Regexp.quote('https://-redacted-:-redacted-@buildpacks.cloudfoundry.org/concourse-binaries/python/python-') + '[\d\.]+' + Regexp.quote('-linux-x64.tgz')) }

      it 'does not include credentials in logged dependency uris' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to have_logged(python_uri)
      end
    end

    context "using a cached buildpack" do
      let(:caching)        { :cached }
      let(:credential_uri) { Regexp.new('https___login_password') }
      let(:python_uri)     { Regexp.new(Regexp.quote('https___-redacted-_-redacted-@buildpacks.cloudfoundry.org_concourse-binaries_python_python-') + '[\d\.]+' + Regexp.quote('-linux-x64.tgz')) }

      it 'does not include credentials in logged dependency file paths' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to have_logged(python_uri)
      end
    end
  end

  describe 'deploying an app that has an executable .profile script' do
    let(:stack)          { 'cflinuxfs2' }
    let(:python_version) { dependency_versions_in_manifest('python', 'python', stack).last }
    let(:app) do
      app_template = generate_python_app(python_version)
      add_dot_profile_script_to_app(app_template.full_path)
      deploy_app(template: app_template, stack: stack, buildpack: 'python-brat-buildpack')
    end

    before(:all) do
      skip_if_no_dot_profile_support_on_targeted_cf
      cleanup_buildpack(buildpack: 'python')
      install_buildpack(buildpack: 'python')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'executes the .profile script' do
      expect(app).to have_logged("PROFILE_SCRIPT_IS_PRESENT_AND_RAN")
    end
  end
end
