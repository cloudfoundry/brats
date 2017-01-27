require 'spec_helper'
require 'bcrypt'

def generate_jruby_app(ruby_version, jruby_version)
  template = JRubyTemplateApp.new(ruby_version, jruby_version)
  template.generate!
  template
end

RSpec.shared_examples :a_deploy_of_jruby_app_to_cf do |ruby_version, jruby_version, stack|
  context "with JRuby version #{jruby_version} and Ruby version #{ruby_version}", version: ruby_version do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      app_template = generate_jruby_app(ruby_version, jruby_version)
      @app = deploy_app(template: app_template, stack: stack, buildpack: 'ruby-brat-buildpack')
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

    if is_current_user_language_tag?('ruby')
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
  end

  describe 'staging with custom buildpack that uses credentials in manifest dependency uris' do
    let(:stack)          { 'cflinuxfs2' }
    let(:jruby_version_string) { dependency_versions_in_manifest('ruby', 'jruby', stack).last }
    let(:app) do
      jruby_version_string.match(/ruby-(.*)-jruby-(.*)/)
      ruby_version = $1
      jruby_version = $2
      app_template = generate_jruby_app(ruby_version, jruby_version)
      @app = deploy_app(template: app_template, stack: stack, buildpack: 'ruby-brat-buildpack')
    end

    before do
      cleanup_buildpack(buildpack: 'ruby')
      install_buildpack_with_uri_credentials(buildpack: 'ruby', buildpack_caching: caching)
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    context "using an uncached buildpack" do
      let(:caching)        { :uncached }
      let(:credential_uri) { Regexp.new(Regexp.quote('https://') + 'login:password@') }
      let(:jruby_uri)      { Regexp.new(Regexp.quote('https://-redacted-:-redacted-@buildpacks.cloudfoundry.org/dependencies/') +
                                        '(manual-binaries\/)?' +
                                        Regexp.quote('jruby/jruby-') + '[\d\.]+' +
                                        Regexp.quote('_ruby-') + '[\d\.]+' + Regexp.quote('-linux-x64-') + '[\da-f]+\.tgz') }

      it 'does not include credentials in logged dependency uris' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to have_logged(jruby_uri)
      end
    end

    context "using a cached buildpack" do
      let(:caching)        { :cached }
      let(:credential_uri) { Regexp.new('https___login_password') }
      let(:jruby_uri)      { Regexp.new(Regexp.quote('https___-redacted-_-redacted-@buildpacks.cloudfoundry.org_dependencies_') +
                                        '(manual-binaries_)?' +
                                        Regexp.quote('jruby_jruby-') + '[\d\.]+' +
                                        Regexp.quote('_ruby-') + '[\d\.]+' + Regexp.quote('-linux-x64-') + '[\da-f]+\.tgz') }

      it 'does not include credentials in logged dependency file paths' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to have_logged(jruby_uri)
      end
    end
  end

  describe 'deploying an app that has an executable .profile script' do
    let(:stack)          { 'cflinuxfs2' }
    let(:jruby_version_string) { dependency_versions_in_manifest('ruby', 'jruby', stack).last }
    let(:app) do
      jruby_version_string.match(/ruby-(.*)-jruby-(.*)/)
      ruby_version = $1
      jruby_version = $2
      app_template = generate_jruby_app(ruby_version, jruby_version)
      add_dot_profile_script_to_app(app_template.full_path)
      deploy_app(template: app_template, stack: stack, buildpack: 'ruby-brat-buildpack')
    end
    let(:browser) { Machete::Browser.new(app) }

    before(:all) do
      skip_if_no_dot_profile_support_on_targeted_cf
      cleanup_buildpack(buildpack: 'ruby')
      install_buildpack(buildpack: 'ruby')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'executes the .profile script' do
      expect(app).to have_logged("PROFILE_SCRIPT_IS_PRESENT_AND_RAN")
    end

    it 'does not let me view the .profile script' do
      browser.visit_path('/.profile')
      expect(browser).to_not have_body 'PROFILE_SCRIPT_IS_PRESENT_AND_RAN'
    end
  end

  describe 'deploying an app that has sensitive environment variables' do
    let(:stack)          { 'cflinuxfs2' }
    let(:jruby_version_string) { dependency_versions_in_manifest('ruby', 'jruby', stack).last }
    let(:app) do
      jruby_version_string.match(/ruby-(.*)-jruby-(.*)/)
      ruby_version = $1
      jruby_version = $2
      app_template = generate_jruby_app(ruby_version, jruby_version)
      add_dot_profile_script_to_app(app_template.full_path)
      deploy_app(template: app_template, stack: stack, buildpack: 'ruby-brat-buildpack')
    end

    before(:all) do
      cleanup_buildpack(buildpack: 'ruby')
      install_buildpack(buildpack: 'ruby')
    end

    it 'will not write credentials to the app droplet' do
      expect(app).to be_running
      expect(app.name).to keep_credentials_out_of_droplet
    end
  end
end
