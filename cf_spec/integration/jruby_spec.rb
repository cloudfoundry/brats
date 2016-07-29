require 'spec_helper'
require 'bcrypt'

def deploy_jruby_app(ruby_version,jruby_version,stack)
  template = JRubyTemplateApp.new(ruby_version,jruby_version)
  template.generate!

  Machete.deploy_app(
    template.path,
    name: template.name,
    buildpack: 'ruby-brat-buildpack',
    stack: stack
  )
end


RSpec.shared_examples :a_deploy_of_jruby_app_to_cf do |ruby_version, jruby_version, stack|
  context "with JRuby version #{jruby_version} and Ruby version #{ruby_version}", version: ruby_version do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      @app = deploy_jruby_app(ruby_version, jruby_version, stack)
    end

    after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

    it 'installs the correct version of JRuby' do
      expect(@app).to be_running
      expect(@app).to have_logged "Using Ruby version: ruby-#{ruby_version}-jruby-#{jruby_version}"
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

        expect(browser).to have_body('The connection attempt failed.')
      end
    end

    it 'supports mysql' do
      2.times do
        browser.visit_path('/mysql')

        expect(browser).to have_body('Communications link failure')
      end
    end
  end
end

describe 'For JRuby in the ruby buildpack', language: 'ruby' do
  describe 'For all supported JRuby versions' do
    before(:all) do
      cleanup_buildpack(buildpack: 'ruby')
      install_buildpack(buildpack: 'ruby')
    end

    ['cflinuxfs2'].each do |stack|
      context "On #{stack} stack", stack: stack do

      jruby_versions = dependency_versions_in_manifest('ruby','jruby',stack)

      jruby_versions.each do |jruby_version_string|
          match_data = jruby_version_string.match(/ruby-(.*)-jruby-(.*)/)
          ruby_version = match_data[1]
          jruby_version = match_data[2]
          it_behaves_like :a_deploy_of_jruby_app_to_cf, ruby_version, jruby_version, stack
        end
      end
    end
  end

  describe 'staging with custom buildpack that uses credentials in manifest dependency uris' do
    [:uncached].each do |caching|
      context "using a #{caching} buildpack" do
        let(:stack) { 'cflinuxfs2' }
        let(:jruby_version_string) { dependency_versions_in_manifest('ruby', 'jruby', stack).last }
        let(:app) do
          jruby_version_string.match(/ruby-(.*)-jruby-(.*)/)
          ruby_version = $1
          jruby_version = $2
          deploy_jruby_app(ruby_version, jruby_version, stack)
        end

        before do
          cleanup_buildpack(buildpack: 'ruby')
          install_buildpack_with_uri_credentials(buildpack: 'ruby', buildpack_caching: caching)
        end

        after { Machete::CF::DeleteApp.new.execute(app) }

        it 'does not include credentials in logged dependency uris' do
          credential_uri = Regexp.new(Regexp.quote('https://') + 'login:password[@]')
          jruby_uri = Regexp.new(Regexp.quote('https://-redacted-:-redacted-@buildpacks.cloudfoundry.org/concourse-binaries/jruby/jruby-') + '[\d\.]+' +
                                     Regexp.quote('_ruby-') + '[\d\.]+' + Regexp.quote('-linux-x64.tgz'))

          expect(app).to_not have_logged(credential_uri)
          expect(app).to have_logged(jruby_uri)
        end
      end
    end
  end
end
