require 'spec_helper'
require 'bcrypt'

def generate_staticfile_app
  template = StaticfileTemplateApp.new()
  template.generate!
  template
end

describe 'For the staticfile buildpack', language: 'staticfile' do
  after(:all) do
    cleanup_buildpack(buildpack: 'staticfile')
  end

  describe 'deploying an app with an updated version of the same buildpack' do
    let(:stack)         { 'cflinuxfs2' }
    let(:app) do
      app_template = generate_staticfile_app
      deploy_app(template: app_template, stack: stack, buildpack: 'staticfile-brat-buildpack')
    end

    before(:all) do
      cleanup_buildpack(buildpack: 'staticfile')
      install_buildpack(buildpack: 'staticfile')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'prints useful warning message to stdout' do
      expect(app).to_not have_logged(/WARNING.* buildpack version changed from/)
      bump_buildpack_version(buildpack: 'staticfile')
      Machete.push(app)
      expect(app).to have_logged(/WARNING.* buildpack version changed from/)
    end
  end

  describe 'staging with custom buildpack that uses credentials in manifest dependency uris' do
    let(:stack)         { 'cflinuxfs2' }
    let(:nginx_version) { dependency_versions_in_manifest('staticfile', 'nginx', stack).last }
    let(:app) do
      app_template = generate_staticfile_app
      deploy_app(template: app_template, stack: stack, buildpack: 'staticfile-brat-buildpack')
    end

    before do
      cleanup_buildpack(buildpack: 'staticfile')
      install_buildpack_with_uri_credentials(buildpack: 'staticfile', buildpack_caching: caching)
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    context "using an uncached buildpack" do
      let(:caching)        { :uncached }
      let(:credential_uri) { Regexp.new(Regexp.quote('https://') + 'login:password[@]') }
      let(:staticfile_uri) { Regexp.new(Regexp.quote('https://-redacted-:-redacted-@buildpacks.cloudfoundry.org/dependencies/nginx/nginx-') + '[\d\.]+' + Regexp.quote('-linux-x64-') + '[\da-f]+' + Regexp.quote('.tgz')) }

      it 'does not include credentials in logged dependency uris' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to_not have_logged('password')
        expect(app).to have_logged(staticfile_uri)
      end
    end

    context "using a cached buildpack" do
      let(:caching)        { :cached }
      let(:credential_uri) { Regexp.new('https___login_password') }
      let(:staticfile_uri) { Regexp.new('/nginx-[\d\.]+-linux-x64-[0-9a-f]+.tgz') }


      it 'does not include credentials in logged dependency file paths' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to_not have_logged('password')
        expect(app).to have_logged(staticfile_uri)
      end
    end
  end

  describe 'deploying an app that has an executable .profile script' do
    let(:stack)          { 'cflinuxfs2' }
    let(:app) do
      app_template = generate_staticfile_app
      add_dot_profile_script_to_app(app_template.full_path)
      deploy_app(template: app_template, stack: stack, buildpack: 'staticfile-brat-buildpack')
    end
    let(:browser) { Machete::Browser.new(app) }

    before(:all) do
      skip_if_no_dot_profile_support_on_targeted_cf
      cleanup_buildpack(buildpack: 'staticfile')
      install_buildpack(buildpack: 'staticfile')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'executes the .profile script' do
      expect(app).to have_logged("PROFILE_SCRIPT_IS_PRESENT_AND_RAN")
    end

    it 'does not let me view the .profile script' do
      browser.visit_path('/.profile', allow_404: true)
      expect(browser).to_not have_body 'PROFILE_SCRIPT_IS_PRESENT_AND_RAN'
    end
  end

  describe 'deploying an app that has sensitive environment variables' do
    let(:stack)          { 'cflinuxfs2' }
    let(:app) do
      app_template = generate_staticfile_app
      deploy_app(template: app_template, stack: stack, buildpack: 'staticfile-brat-buildpack')
    end

    before(:all) do
      cleanup_buildpack(buildpack: 'staticfile')
      install_buildpack(buildpack: 'staticfile')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'will not write credentials to the app droplet' do
      expect(app).to be_running
      expect(app.name).to keep_credentials_out_of_droplet
    end
  end
end
