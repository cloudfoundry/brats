require 'spec_helper'

describe 'For the java buildpack', language: 'java' do
  # java buildpack doesn't have a VERSION file
  before(:all) do
    @old_buildpack_version = ENV['BUILDPACK_VERSION']
    ENV['BUILDPACK_VERSION'] = 'not_relevant'

    cleanup_buildpack(buildpack: 'java')
    install_java_buildpack(position: 1)
  end

  after(:all) do
    cleanup_buildpack(buildpack: 'java')
    ENV['BUILDPACK_VERSION'] = @old_buildpack_version
  end

  describe 'deploying an app that has sensitive environment variables' do
    before do
      template = JavaTemplateApp.new
      @app = Machete.deploy_app(
        template.path,
        name: template.name,
        manifest: template.manifest,
        service: true,
        buildpack: 'java-brat-buildpack',
        skip_verify_version: true
      )
    end

    after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

    it 'will not write credentials to the app droplet' do
      expect(@app).to be_running
      expect(@app.name).to keep_credentials_out_of_droplet
    end
  end
end
