require 'spec_helper'
require 'bcrypt'

def generate_binary_app
  template = BinaryTemplateApp.new()
  template.generate!
  template
end

describe 'For the binary buildpack', language: 'binary' do
  after(:all) do
    cleanup_buildpack(buildpack: 'binary')
  end

  describe 'deploying an app with an updated version of the same buildpack' do
    let(:stack)         { 'cflinuxfs2' }
    let(:app) do
      app_template = generate_binary_app
      deploy_app(template: app_template, stack: stack, buildpack: 'binary-brat-buildpack')
    end

    before(:all) do
      cleanup_buildpack(buildpack: 'binary')
      install_buildpack(buildpack: 'binary')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'prints useful warning message to stdout' do
      expect(app).to_not have_logged('WARNING: buildpack version changed from')
      bump_buildpack_version(buildpack: 'binary')
      Machete.push(app)
      expect(app).to have_logged('WARNING: buildpack version changed from')
    end
  end

  describe 'deploying an app that has an executable .profile script' do
    let(:stack)          { 'cflinuxfs2' }
    let(:app) do
      app_template = generate_binary_app
      add_dot_profile_script_to_app(app_template.full_path)
      deploy_app(template: app_template, stack: stack, buildpack: 'binary-brat-buildpack')
    end
    let(:browser) { Machete::Browser.new(app) }

    before(:all) do
      skip_if_no_dot_profile_support_on_targeted_cf
      cleanup_buildpack(buildpack: 'binary')
      install_buildpack(buildpack: 'binary')
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
    let(:app) do
      app_template = generate_binary_app
      deploy_app(template: app_template, stack: stack, buildpack: 'binary-brat-buildpack')
    end

    before(:all) do
      cleanup_buildpack(buildpack: 'binary')
      install_buildpack(buildpack: 'binary')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'will not write credentials to the app droplet' do
      expect(app).to be_running
      expect(app.name).to keep_credentials_out_of_droplet
    end
  end
end
