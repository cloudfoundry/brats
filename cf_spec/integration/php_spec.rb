require 'spec_helper'

def generate_php_app(php_version, web_server, web_server_version)
  template = PHPTemplateApp.new(
    runtime_version: php_version,
    web_server: web_server,
    web_server_version: web_server_version
  )
  template.generate!
  template
end

RSpec.shared_examples :a_deploy_of_php_app_to_cf do |php_version, web_server_binary, stack|
  web_server         = web_server_binary['name']
  web_server_version = web_server_binary['version']

  context "with php-#{php_version} and web_server: #{web_server}-#{web_server_version}", version: php_version do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      app_template = generate_php_app(php_version, web_server, web_server_version)
      @app = deploy_app(template: app_template, stack: stack, buildpack: 'php-brat-buildpack')
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
      expect(@app).to have_logged('Installing PHP')
      expect(@app).to have_logged("PHP #{php_version}")
    end

    it 'should load all of the modules specified in options.json' do
      browser.visit_path("/?#{@options['PHP_EXTENSIONS'].join(',')}")
      @options['PHP_EXTENSIONS'].each do |extension|
        expect(browser).to have_body("SUCCESS: #{extension} loads")
      end
    end

    it 'should not include any warning messages when loading all the extensions' do
      expect(@app).to_not have_logged(/The extension .* is not provided by this buildpack./)
    end

    it 'should not load unknown module' do
      browser.visit_path('/?something')
      expect(browser).to have_body('ERROR: something failed to load.')
    end
  end
end

describe 'For the php buildpack', language: 'php' do
  describe 'For all supported PHP versions' do
    before(:all) do
      cleanup_buildpack(buildpack: 'php')
      install_buildpack(buildpack: 'php')
    end

    valid_web_servers  = %w(httpd nginx)

    ['cflinuxfs2'].each do |stack|
      context "on the #{stack} stack", stack: stack do
        php_versions = dependency_versions_in_manifest('php', 'php', stack)

        dependencies = parsed_manifest(buildpack: 'php').fetch('dependencies')
        web_servers  = dependencies.select { |binary| valid_web_servers.include?(binary['name']) && binary['cf_stacks'].include?('cflinuxfs2') }

        php_versions.each do |php_version|
          web_servers.each do |web_server|
            it_behaves_like :a_deploy_of_php_app_to_cf, php_version, web_server, stack
          end
        end
      end
    end
  end

  describe 'staging with custom buildpack that uses credentials in manifest dependency uris' do
    let(:stack)         { 'cflinuxfs2' }
    let(:php_version)   { dependency_versions_in_manifest('php', 'php', stack).last }
    let(:major_version) { php_version.split(".").first }
    let(:php_in_uri)    { major_version == '7' ? 'php7' : 'php' }

    let(:app) do
      nginx_version = dependency_versions_in_manifest('php', 'nginx', stack).last
      app_template = generate_php_app(php_version, 'nginx', nginx_version)
      deploy_app(template: app_template, stack: stack, buildpack: 'php-brat-buildpack')
    end

    before do
      cleanup_buildpack(buildpack: 'php')
      install_buildpack_with_uri_credentials(buildpack: 'php', buildpack_caching: caching)
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    context "using an uncached buildpack" do
      let(:caching)        { :uncached }
      let(:credential_uri) { Regexp.new(Regexp.quote('https://') + 'login:password[@]') }
      let(:php_uri)        { Regexp.new(Regexp.quote("https://-redacted-:-redacted-@buildpacks.cloudfoundry.org/concourse-binaries/#{php_in_uri}/#{php_in_uri}-") + '[\d\.]+' + Regexp.quote('-linux-x64-') + '[\d]+\.tgz') }

      it 'does not include credentials in logged dependency uris' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to have_logged(php_uri)
      end
    end

    context "using a cached buildpack" do
      let(:caching)        { :cached }
      let(:credential_uri) { Regexp.new('https___login_password') }
      let(:php_uri)        { Regexp.new(Regexp.quote("https___-redacted-_-redacted-@buildpacks.cloudfoundry.org_concourse-binaries_#{php_in_uri}_#{php_in_uri}-") + '[\d\.]+' + Regexp.quote('-linux-x64-') + '[\d]+\.tgz') }

      it 'does not include credentials in logged dependency file paths' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to have_logged(php_uri)
      end
    end
  end

  describe 'deploying an app that has an executable .profile script' do
    let(:stack)          { 'cflinuxfs2' }
    let(:php_version)   { dependency_versions_in_manifest('php', 'php', stack).last }
    let(:app) do
      nginx_version = dependency_versions_in_manifest('php', 'nginx', stack).last
      app_template = generate_php_app(php_version, 'nginx', nginx_version)
      add_dot_profile_script_to_app(app_template.full_path)
      deploy_app(template: app_template, stack: stack, buildpack: 'php-brat-buildpack')
    end

    before(:all) do
      skip_if_no_dot_profile_support_on_targeted_cf
      cleanup_buildpack(buildpack: 'php')
      install_buildpack(buildpack: 'php')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'executes the .profile script' do
      expect(app).to have_logged("PROFILE_SCRIPT_IS_PRESENT_AND_RAN")
    end
  end

end
