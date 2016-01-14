require 'spec_helper'

describe 'For all supported Go versions', language: 'go' do
  before(:all) { install_buildpack(buildpack: 'go') }
  after(:all) { cleanup_buildpack(buildpack: 'go') }

  def self.dependencies
    parsed_manifest(buildpack: 'go').fetch('dependencies')
  end

  def self.create_test_for(test_name, options = {})
    context "with #{test_name}" do
      let(:version) { options[:version] }
      let(:app) do
        template = GoTemplateApp.new(version)
        template.generate!

        Machete.deploy_app(
          template.path,
          name: template.name,
          buildpack: 'go-brat-buildpack',
          stack: stack
        )
      end
      let(:browser) { Machete::Browser.new(app) }

      after { Machete::CF::DeleteApp.new.execute(app) }

      it 'runs a simple webserver', version: options[:version] do
        assert_correct_version_installed(version)
        assert_root_contains('Hello, World')
      end
    end
  end

  context 'On cflinuxfs2 stack', stack: 'cflinuxfs2' do
    let(:stack) { 'cflinuxfs2' }

    dependencies.each do |dependency|
      if dependency['name'] == 'go'
        create_test_for("#{dependency['name']} #{dependency['version']}", version: dependency['version'])
      end
    end
  end


  def assert_correct_version_installed(version)
    expect(app).to be_running(120)
    expect(app).to have_logged "Installing go#{version}"
  end

  def assert_root_contains(text)
    2.times do
      browser.visit_path('/')
      expect(browser).to have_body(text)
    end
  end

end
