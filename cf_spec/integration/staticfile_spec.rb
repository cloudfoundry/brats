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
    [:uncached].each do |caching|
      context "using a #{caching} buildpack" do
        let(:stack) { 'cflinuxfs2' }
        let(:nginx_version) { dependency_versions_in_manifest('staticfile', 'nginx', stack).last }
        let(:app) { deploy_staticfile_app(stack) }

        before do
          cleanup_buildpack(buildpack: 'staticfile')
          install_buildpack_with_uri_credentials(buildpack: 'staticfile', buildpack_caching: caching)
        end

        after { Machete::CF::DeleteApp.new.execute(app) }

        it 'does not include credentials in logged dependency uris' do
          credential_uri = Regexp.new(Regexp.quote('https://') + 'login:password[@]')
          staticfile_uri = Regexp.new(Regexp.quote('https://-redacted-:-redacted-@buildpacks.cloudfoundry.org/concourse-binaries/nginx/nginx-') + '[\d\.]+' + Regexp.quote('-linux-x64.tgz'))

          expect(app).to_not have_logged(credential_uri)
          expect(app).to have_logged(staticfile_uri)
        end
      end
    end
  end
end
