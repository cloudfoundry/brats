require 'spec_helper'

def deploy_app(go_version, stack)
  template = GoTemplateApp.new(go_version)
  template.generate!

  Machete.deploy_app(
    template.path,
    name: template.name,
    buildpack: 'go-brat-buildpack',
    stack: stack
  )
end

RSpec.shared_examples :a_deploy_of_go_app_to_cf do |go_version, stack|
  context "with Go version #{go_version}" do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      @app = deploy_app(go_version, stack)
    end

    after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

    it 'runs a simple webserver with correct go version' do
      expect(@app).to be_running(120)
      expect(@app).to have_logged "Installing go#{go_version}"
    end

    it 'has content at the root' do
      2.times do
        browser.visit_path('/')
        expect(browser).to have_body('Hello, World')
      end
    end
  end
end

describe 'For all supported Go versions', language: 'go' do
  let(:stack) { 'cflinuxfs2' }

  before(:all) do
    cleanup_buildpack(buildpack: 'go')
    install_buildpack(buildpack: 'go')
  end

  ['cflinuxfs2'].each do |stack|
    context "on the #{stack} stack", stack: stack do
      go_versions = dependency_versions_in_manifest('go','go',stack)
      go_versions.each do |go_version|
        it_behaves_like :a_deploy_of_go_app_to_cf, go_version, stack
      end
    end
  end
end
