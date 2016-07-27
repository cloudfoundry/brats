require 'spec_helper'
require 'bcrypt'

def deploy_app(ruby_version, stack)
  template = RubyTemplateApp.new(ruby_version)
  template.generate!

  Machete.deploy_app(
    template.path,
    name: template.name,
    buildpack: 'ruby-brat-buildpack',
    stack: stack
  )
end

RSpec.shared_examples :a_deploy_of_ruby_app_to_cf do |ruby_version, stack|
  context "with Ruby version #{ruby_version}", version: ruby_version do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      @app = deploy_app(ruby_version, stack)
    end

    after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

    it 'installs the correct version of Ruby' do
      expect(@app).to be_running
      expect(@app).to have_logged "Using Ruby version: ruby-#{ruby_version}"
    end

    it 'runs a simple webserver' do
      2.times do
        browser.visit_path('/')
        expect(browser).to have_body('Hello, World')
      end
    end

    it 'parses XML with nokogiri' do
      2.times do
        browser.visit_path('/nokogiri')
        expect(browser).to have_body('Hello, World')
      end
    end

    it 'supports EventMachine' do
      2.times do
        browser.visit_path('/em')
        expect(browser).to have_body('Hello, EventMachine')
      end
    end

    it 'encrypts with bcrypt' do
      2.times do
        browser.visit_path('/bcrypt')
        crypted_text = BCrypt::Password.new(browser.body)
        expect(crypted_text).to eq 'Hello, bcrypt'
      end
    end

    it 'supports bson' do
      2.times do
        browser.visit_path('/bson')
        expect(browser).to have_body('00040000')
      end
    end

    it 'supports postgres' do
      2.times do
        browser.visit_path('/pg')

        expect(browser).to have_body('could not connect to server: No such file or directory')
      end
    end

    it 'supports mysql' do
      2.times do
        browser.visit_path('/mysql')

        expect(browser).to have_body("Unknown MySQL server host 'testing'")
      end
    end
  end
end

describe 'For the ruby buildpack', language: 'ruby' do
  describe 'For all supported Ruby versions' do
    before(:all) do
      cleanup_buildpack(buildpack: 'ruby')
      install_buildpack(buildpack: 'ruby')
    end

    ['cflinuxfs2'].each do |stack|
      context "on the #{stack} stack", stack: stack do
        ruby_versions = dependency_versions_in_manifest('ruby', 'ruby', stack)
        ruby_versions.each do |ruby_version|
          it_behaves_like :a_deploy_of_ruby_app_to_cf, ruby_version, stack
        end
      end
    end
  end

  describe 'staging with custom buildpack that uses credentials in manifest dependency uris' do
    let(:stack)          { 'cflinuxfs2' }
    let(:ruby_version) { dependency_versions_in_manifest('ruby', 'ruby', stack).last }
    let(:app)            { deploy_app(ruby_version, stack) }

    before do
      cleanup_buildpack(buildpack: 'ruby')
      install_buildpack_with_uri_credentials(buildpack: 'ruby')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'does not include credentials in logged dependency uris' do
      credential_uri = Regexp.new(Regexp.quote('https://') + 'login:password[@]')
      ruby_uri = Regexp.new(Regexp.quote('https://-redacted-:-redacted-@buildpacks.cloudfoundry.org/concourse-binaries/ruby/ruby-') + '[\d\.]+' + Regexp.quote('-linux-x64.tgz'))

      expect(app).to_not have_logged(credential_uri)
      expect(app).to have_logged(ruby_uri)
    end
  end
end
