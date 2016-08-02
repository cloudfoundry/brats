require 'spec_helper'
require 'bcrypt'

def deploy_staticfile_app(stack)
  template = StaticfileTemplateApp.new()
  template.generate!

  Machete.deploy_app(
    template.path,
    name: template.name,
    buildpack: 'staticfile-brat-buildpack',
    stack: stack
  )
end

describe 'For the staticfile buildpack', language: 'staticfile' do
  describe 'staging with custom buildpack that uses credentials in manifest dependency uris' do
    let(:stack)         { 'cflinuxfs2' }
    let(:nginx_version) { dependency_versions_in_manifest('staticfile', 'nginx', stack).last }
    let(:app)           { deploy_staticfile_app(stack) }

    before do
      cleanup_buildpack(buildpack: 'staticfile')
      install_buildpack_with_uri_credentials(buildpack: 'staticfile', buildpack_caching: caching)
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    context "using an uncached buildpack" do
      let(:caching)        { :uncached }
      let(:credential_uri) { Regexp.new(Regexp.quote('https://') + 'login:password[@]') }
      let(:staticfile_uri) { Regexp.new(Regexp.quote('https://-redacted-:-redacted-@buildpacks.cloudfoundry.org/concourse-binaries/nginx/nginx-') + '[\d\.]+' + Regexp.quote('-linux-x64.tgz')) }

      it 'does not include credentials in logged dependency uris' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to have_logged(staticfile_uri)
      end
    end

    context "using a cached buildpack" do
      let(:caching)        { :cached }
      let(:credential_uri) { Regexp.new('https___login_password') }
      let(:staticfile_uri) { Regexp.new(Regexp.quote('https___-redacted-_-redacted-@buildpacks.cloudfoundry.org_concourse-binaries_nginx_nginx-') + '[\d\.]+' + Regexp.quote('-linux-x64.tgz')) }

      it 'does not include credentials in logged dependency file paths' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to have_logged(staticfile_uri)
      end
    end
  end
end
