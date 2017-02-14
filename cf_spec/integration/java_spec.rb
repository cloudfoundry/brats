require 'spec_helper'

describe 'For the java buildpack', language: 'java' do
  after(:all) do
    cleanup_buildpack(buildpack: 'java')
  end

  describe 'deploying an app that has sensitive environment variables' do
    let(:app) do
      template = JavaTemplateApp.new
      Machete.deploy_app(
        template.path,
        name: template.name,
        service: true
      )
    end

    before(:all) do
      cleanup_buildpack(buildpack: 'java')
      install_java_buildpack(position: 1)
    end

    it 'will not write credentials to the app droplet' do
      expect(app).to be_running
      expect(app.name).to keep_credentials_out_of_droplet
    end
  end
end
