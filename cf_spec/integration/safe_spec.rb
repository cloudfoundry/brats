require 'spec_helper'

RSpec.describe 'When testing for safeness of a buildpack' do
  before do
    cleanup_buildpack(buildpack: buildpack_name)
    if buildpack_name == 'java'
      install_java_buildpack(position: 1)
    else
      install_buildpack(buildpack: buildpack_name, position: 1)
    end
  end

  after { Machete::CF::DeleteApp.new.execute(@app) }

  context 'a Python app' do
    let(:buildpack_name) { 'python' }

    it 'will be safe' do
      manifest     = parsed_manifest(buildpack: buildpack_name)
      python_version = manifest['dependencies'].find{ |d| d['name'] == 'python' }['version']

      template = PythonTemplateApp.new(python_version)
      template.generate!

      @app = Machete.deploy_app(
        template.path,
        name: template.name,
        service: true
      )

      expect(@app).to be_running
      expect(template.name).to keep_credentials_out_of_droplet
    end
  end

  context 'a golang app' do
    let(:buildpack_name) { 'go' }

    it 'will be safe' do
      manifest     = parsed_manifest(buildpack: buildpack_name)
      go_version = manifest['dependencies'].find{ |d| d['name'] == 'go' }['version']

      template = GoTemplateApp.new(go_version)
      template.generate!

      @app = Machete.deploy_app(
        template.path,
        name: template.name,
        service: true
      )

      expect(@app).to be_running
      expect(template.name).to keep_credentials_out_of_droplet
    end
  end

  context 'a PHP app' do
    let(:buildpack_name) { 'php' }

    it 'will be safe' do
      manifest     = parsed_manifest(buildpack: buildpack_name)
      php_version = manifest['dependencies'].find{ |d| d['name'] == 'php' }['version']
      nginx_version = manifest['dependencies'].find{ |d| d['name'] == 'nginx' }['version']

      template = PHPTemplateApp.new(
        runtime_version: php_version,
        web_server: 'nginx',
        web_server_version: nginx_version
      )
      template.generate!

      @app = Machete.deploy_app(
        template.path,
        name: template.name,
        service: true
      )

      expect(@app).to be_running
      expect(template.name).to keep_credentials_out_of_droplet
    end
  end

  context 'a nodeJS app' do
    let(:buildpack_name) { 'nodejs' }

    it 'will be safe' do
      manifest     = parsed_manifest(buildpack: buildpack_name)
      nodejs_version = manifest['dependencies'].find{ |d| d['name'] == 'node' }['version']

      template = NodeJSTemplateApp.new(nodejs_version)
      template.generate!

      @app = Machete.deploy_app(
        template.path,
        name: template.name,
        service: true
      )

      expect(@app).to be_running
      expect(template.name).to keep_credentials_out_of_droplet
    end
  end

  context 'a staticfile app' do
    let(:buildpack_name) { 'staticfile' }

    it 'will be safe' do
      template = StaticfileTemplateApp.new
      template.generate!

      @app = Machete.deploy_app(
        template.path,
        name: template.name,
        service: true
      )

      expect(@app).to be_running
      expect(template.name).to keep_credentials_out_of_droplet
    end

  end

  context 'a Ruby app' do
    let(:buildpack_name) { 'ruby' }

    it 'will be safe' do
      manifest     = parsed_manifest(buildpack: buildpack_name)
      ruby_version = manifest['dependencies'].find{ |d| d['name'] == 'ruby' }['version']

      template = RubyTemplateApp.new(ruby_version)
      template.generate!

      @app = Machete.deploy_app(
        template.path,
        name: template.name,
        service: true
      )

      expect(@app).to be_running
      expect(template.name).to keep_credentials_out_of_droplet
    end
  end

  context 'a Java app' do
    let(:buildpack_name) { 'java' }

    it 'will be safe' do
      template = JavaTemplateApp.new

      @app = Machete.deploy_app(
        template.path,
        name: template.name,
        service: true
      )

      expect(@app).to be_running
      expect(template.name).to keep_credentials_out_of_droplet
    end
  end
end
