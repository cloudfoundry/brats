require 'spec_helper'
require 'bcrypt'

RSpec.shared_examples :a_deploy_of_python_app_to_cf do |python_version, stack|
  context "with Python version #{python_version}" do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      @template = PythonTemplateApp.new(python_version)
      @template.generate!

      @app = Machete.deploy_app(
        @template.path,
        name: @template.name,
        buildpack: 'python-brat-buildpack',
        stack: stack
      )
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

    context 'staging with custom buildpack that uses credentials in manifest dependency uris' do
      before do
        cleanup_buildpack(buildpack: 'python')
        install_buildpack_with_uri_credentials(buildpack: 'python')
        @app = Machete.deploy_app(
          @template.path,
          name: @template.name,
          buildpack: 'python-brat-buildpack',
          stack: stack
        )
      end

      it 'does not include credentials in logged dependency uris' do
        credential_uri = Regexp.new(Regexp.quote('https://') + 'login:password[@]')
        python_uri = Regexp.new(Regexp.quote('https://-redacted-:-redacted-@buildpacks.cloudfoundry.org/concourse-binaries/python/python-') + '[\d\.]+' + Regexp.quote('-linux-x64.tgz'))

        expect(@app).to_not have_logged(credential_uri)
        expect(@app).to have_logged(python_uri)
      end
    end
  end
end

describe 'For all supported Python versions', language: 'python' do
  before(:all) do
    cleanup_buildpack(buildpack: 'python')
    install_buildpack(buildpack: 'python')
  end

  def self.dependencies
    parsed_manifest(buildpack: 'python')
      .fetch('dependencies')
  end

  ['cflinuxfs2'].each do |stack|
    context "on the #{stack} stack", stack: stack do
      dependencies.select { |d| d['name'] == 'python' && d['cf_stacks'].include?(stack) }.each do |dependency|
        it_behaves_like :a_deploy_of_python_app_to_cf, dependency['version'], stack
      end
    end
  end
end
