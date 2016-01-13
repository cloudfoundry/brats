require 'spec_helper'

RSpec.describe 'When testing for safeness of a buildpack' do
  context 'a Ruby app' do
    after do
      Machete::CF::DeleteApp.new.execute(@app)
      cleanup_buildpack(buildpack: 'ruby')
    end

    it 'will be safe' do
      install_buildpack(buildpack: 'ruby', position: 1)

      manifest     = parsed_manifest(buildpack: 'ruby')
      ruby_version = manifest['dependencies'].find{ |d| d['name'] == 'ruby' }['version']

      template = RubyTemplateApp.new(ruby_version)
      template.generate!

      @app = Machete.deploy_app(
        template.path,
        name: template.name,
        service: true
      )

      expect(@app).to be_running
      expect(template.name).to be_safe
    end
  end

  context 'a Java app' do
    after do
      Machete::CF::DeleteApp.new.execute(@app)
      cleanup_buildpack(buildpack: 'java')
    end

    it 'will be safe' do
      install_java_buildpack(position: 1)
      template = JavaTemplateApp.new

      @app = Machete.deploy_app(
        template.path,
        name: template.name,
        service: true
      )

      expect(@app).to be_running
      expect(template.name).to be_safe
    end
  end
end
