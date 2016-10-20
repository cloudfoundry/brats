require 'spec_helper'

def generate_dotnet_core_app(dotnet_version, runtime_version)
  template = DotnetCoreTemplateApp.new(dotnet_version, runtime_version)
  template.generate!
  template
end

RSpec.shared_examples :a_deploy_of_dotnet_core_app_to_cf do |dotnet_version, runtime_version, stack|
  context "with .NET SDK version: #{dotnet_version} and .NET runtime version: #{runtime_version}" do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      app_template = generate_dotnet_core_app(dotnet_version, runtime_version)
      @app = deploy_app(template: app_template, stack: stack, buildpack: 'dotnet-core-brat-buildpack')
    end

    after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

    it 'installs the correct version of dotnet' do
      expect(@app).to be_running
      expect(@app).to have_logged "dotnet version: #{dotnet_version}"
    end

    it 'runs a simple webserver' do
      2.times do
        browser.visit_path('/')
        expect(browser).to have_body('Hello World!')
      end
    end
  end
end

describe 'For the .NET Core buildpack', language: 'dotnet-core' do
  describe 'For all supported dotnet versions' do
    before(:all) do
      cleanup_buildpack(buildpack: 'dotnet-core')
      install_buildpack(buildpack: 'dotnet-core')
    end

    ['cflinuxfs2'].each do |stack|
      context "on the #{stack} stack", stack: stack do
        dotnet_versions = dependency_versions_in_manifest('dotnet-core', 'dotnet', stack)
        dotnet_versions.each do |dotnet_version|
          runtime_version = get_runtime_version(dotnet_version: dotnet_version)
          it_behaves_like :a_deploy_of_dotnet_core_app_to_cf, dotnet_version, runtime_version, stack
        end
      end
    end
  end

  describe 'staging with custom buildpack that uses credentials in manifest dependency uris' do
    let(:stack)           { 'cflinuxfs2' }
    let(:dotnet_version)  { dependency_versions_in_manifest('dotnet-core', 'dotnet', stack).last }
    let(:runtime_version) { get_runtime_version(dotnet_version: dotnet_version) }

    let(:app) do
      app_template = generate_dotnet_core_app(dotnet_version, runtime_version)
      deploy_app(template: app_template, stack: stack, buildpack: 'dotnet-core-brat-buildpack')
    end

    before do
      cleanup_buildpack(buildpack: 'dotnet-core')
      install_buildpack_with_uri_credentials(buildpack: 'dotnet-core', buildpack_caching: caching)
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    context "using an uncached buildpack" do
      let(:caching)         { :uncached }
      let(:credential_uri)  { Regexp.new(Regexp.quote('https://') + 'login:password[@]') }
      let(:dotnet_core_uri) { Regexp.new(Regexp.quote('https://-redacted-:-redacted-@buildpacks.cloudfoundry.org/concourse-binaries/dotnet/dotnet.') + '[a-z\d\.-]+' + Regexp.quote('.linux-amd64.tar.gz')) }

      it 'does not include credentials in logged dependency uris' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to have_logged(dotnet_core_uri)
      end
    end

    context "using a cached buildpack" do
      let(:caching)        { :cached }
      let(:credential_uri) { Regexp.new('https___login_password') }
      let(:dotnet_core_uri) { Regexp.new(Regexp.quote('https___-redacted-_-redacted-@buildpacks.cloudfoundry.org_concourse-binaries_dotnet_dotnet.') + '[a-z\d\.-]+' + Regexp.quote('.linux-amd64.tar.gz')) }

      it 'does not include credentials in logged dependency file paths' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to have_logged(dotnet_core_uri)
      end
    end
  end

  describe 'deploying an app that has an executable .profile script' do
    let(:stack)          { 'cflinuxfs2' }
    let(:dotnet_version)  { dependency_versions_in_manifest('dotnet-core', 'dotnet', stack).last }
    let(:runtime_version) { get_runtime_version(dotnet_version: dotnet_version) }

    let(:app) do
      app_template = generate_dotnet_core_app(dotnet_version, runtime_version)
      add_dot_profile_script_to_app(app_template.full_path)
      deploy_app(template: app_template, stack: stack, buildpack: 'dotnet-core-brat-buildpack')
    end

    let(:browser) { Machete::Browser.new(app) }

    before(:all) do
      skip_if_no_dot_profile_support_on_targeted_cf
      cleanup_buildpack(buildpack: 'dotnet-core')
      install_buildpack(buildpack: 'dotnet-core')
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
end
