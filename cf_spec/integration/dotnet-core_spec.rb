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
end
