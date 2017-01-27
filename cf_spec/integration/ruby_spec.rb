require 'spec_helper'
require 'bcrypt'

def generate_ruby_app(ruby_version)
  template = RubyTemplateApp.new(ruby_version)
  template.generate!
  template
end

RSpec.shared_examples :a_deploy_of_ruby_app_to_cf do |ruby_version, stack|
  context "with Ruby version #{ruby_version}", version: ruby_version do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      app_template = generate_ruby_app(ruby_version)
      @app = deploy_app(template: app_template, stack: stack, buildpack: 'ruby-brat-buildpack')
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

    it 'supports mysql2' do
      2.times do
        browser.visit_path('/mysql2')

        expect(browser).to have_body("Unknown MySQL server host 'testing'")
      end
    end
  end
end

describe 'For the ruby buildpack', language: 'ruby' do
  describe 'deploying an app with an updated version of the same buildpack' do
    let(:stack)         { 'cflinuxfs2' }
    let(:ruby_version)  { dependency_versions_in_manifest('ruby', 'ruby', stack).last }
    let(:app) do
      app_template = generate_ruby_app(ruby_version)
      deploy_app(template: app_template, stack: stack, buildpack: 'ruby-brat-buildpack')
    end

    before(:all) do
      cleanup_buildpack(buildpack: 'ruby')
      install_buildpack(buildpack: 'ruby')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'prints useful warning message to stdout' do
      expect(app).to_not have_logged('WARNING: buildpack version changed from')
      bump_buildpack_version(buildpack: 'ruby')
      Machete.push(app)
      expect(app).to have_logged('WARNING: buildpack version changed from')
    end
  end

  describe 'For all supported Ruby versions' do
    before(:all) do
      cleanup_buildpack(buildpack: 'ruby')
      install_buildpack(buildpack: 'ruby')
    end

    if is_current_user_language_tag?('ruby')
      ['cflinuxfs2'].each do |stack|
        context "on the #{stack} stack", stack: stack do
          ruby_versions = dependency_versions_in_manifest('ruby', 'ruby', stack)
          ruby_versions.each do |ruby_version|
            it_behaves_like :a_deploy_of_ruby_app_to_cf, ruby_version, stack
          end
        end
      end
    end
  end

  describe 'staging with ruby buildpack that sets EOL on dependency' do
    let(:stack)      { 'cflinuxfs2' }
    let(:ruby_version) do
      dependency_versions_in_manifest('ruby', 'ruby', stack).sort do |ver1, ver2|
        Gem::Version.new(ver1) <=> Gem::Version.new(ver2)
      end.first
    end
    let(:app) do
      app_template = generate_ruby_app(ruby_version)
      deploy_app(template: app_template, stack: stack, buildpack: 'ruby-brat-buildpack')
    end

    let(:version_line) { ruby_version.gsub(/\.\d+$/,'') }
    let(:eol_date) { (Date.today + 10) }
    let(:warning_message) { /WARNING: ruby #{version_line} will no longer be available in new buildpacks released after/ }

    before do
      cleanup_buildpack(buildpack: 'ruby')
      install_buildpack(buildpack: 'ruby', buildpack_caching: caching) do
        hash = YAML.load_file('manifest.yml')
        hash['dependency_deprecation_dates'] = [{
          'match' => version_line + '\.\d+',
          'version_line' => version_line,
          'name' => 'ruby',
          'date' => eol_date
        }]
        File.write('manifest.yml', hash.to_yaml)
      end
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    context "using an uncached buildpack" do
      let(:caching)        { :uncached }

      it 'warns about end of life' do
        expect(app).to have_logged(warning_message)
      end
    end

    context "using an uncached buildpack" do
      let(:caching)        { :cached }

      it 'warns about end of life' do
        expect(app).to have_logged(warning_message)
      end
    end
  end

  describe 'staging with a version of ruby that is not the latest patch release in the manifest' do
    let(:stack)      { 'cflinuxfs2' }
    let(:ruby_version) do
      dependency_versions_in_manifest('ruby', 'ruby', stack).sort do |ver1, ver2|
        Gem::Version.new(ver1) <=> Gem::Version.new(ver2)
      end.first
    end

    let(:app) do
      app_template = generate_ruby_app(ruby_version)
      deploy_app(template: app_template, stack: stack, buildpack: 'ruby-brat-buildpack')
    end

    before do
      cleanup_buildpack(buildpack: 'ruby')
      install_buildpack(buildpack: 'ruby')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'logs a warning that tells the user to upgrade the dependency' do
      expect(app).to have_logged(/\*\*WARNING\*\* A newer version of ruby is available in this buildpack/)
    end
  end

  describe 'staging with custom buildpack that uses credentials in manifest dependency uris' do
    let(:stack)          { 'cflinuxfs2' }
    let(:ruby_version)   { dependency_versions_in_manifest('ruby', 'ruby', stack).last }
    let(:app) do
      app_template = generate_ruby_app(ruby_version)
      deploy_app(template: app_template, stack: stack, buildpack: 'ruby-brat-buildpack')
    end

    before do
      cleanup_buildpack(buildpack: 'ruby')
      install_buildpack_with_uri_credentials(buildpack: 'ruby', buildpack_caching: caching)
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    context "using an uncached buildpack" do
      let(:caching)        { :uncached }
      let(:credential_uri) { Regexp.new(Regexp.quote('https://') + 'login:password[@]') }
      let(:ruby_uri)       { Regexp.new(Regexp.quote('https://-redacted-:-redacted-@buildpacks.cloudfoundry.org/dependencies/ruby/ruby-') + '[\d\.]+' + Regexp.quote('-linux-x64-') + '[\da-f]+' + Regexp.quote('.tgz')) }

      it 'does not include credentials in logged dependency uris' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to have_logged(ruby_uri)
      end
    end

    context "using a cached buildpack" do
      let(:caching)        { :cached }
      let(:credential_uri) { Regexp.new('https___login_password') }
      let(:ruby_uri)       { Regexp.new(Regexp.quote('https___-redacted-_-redacted-@buildpacks.cloudfoundry.org_dependencies_ruby_ruby-') + '[\d\.]+' + Regexp.quote('-linux-x64-') + '[\da-f]+' + Regexp.quote('.tgz')) }

      it 'does not include credentials in logged dependency file paths' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to have_logged(ruby_uri)
      end
    end
  end

  describe 'deploying an app that has an executable .profile script' do
    let(:stack)          { 'cflinuxfs2' }
    let(:ruby_version)   { dependency_versions_in_manifest('ruby', 'ruby', stack).last }
    let(:app) do
      app_template = generate_ruby_app(ruby_version)
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
    let(:ruby_version)   { dependency_versions_in_manifest('ruby', 'ruby', stack).last }
    let(:app) do
      app_template = generate_ruby_app(ruby_version)
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
