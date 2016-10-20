require 'spec_helper'

RSpec.describe 'during staging' do
  before do
    cleanup_buildpack(buildpack: buildpack_name)
    if buildpack_name == 'java'
      install_java_buildpack(position: 1)
    else
      install_buildpack(buildpack: buildpack_name, position: 1)
    end
  end

  after { Machete::CF::DeleteApp.new.execute(@app) }

  context 'the Python buildpack', language: 'python' do
    let(:buildpack_name) { 'python' }

    it 'will not write credentials to the app droplet' do
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

  context 'the Go buildpack', language: 'go' do
    let(:buildpack_name) { 'go' }

    it 'will not write credentials to the app droplet' do
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

  context 'the PHP buildpack', language: 'php' do
    let(:buildpack_name) { 'php' }

    it 'will not write credentials to the app droplet' do
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

  context 'the NodeJS buildpack', language: 'nodejs' do
    let(:buildpack_name) { 'nodejs' }

    it 'will not write credentials to the app droplet' do
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

  context 'the Staticfile buildpack', language: 'staticfile' do
    let(:buildpack_name) { 'staticfile' }

    it 'will not write credentials to the app droplet' do
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

  context 'the Ruby buildpack', language: 'ruby' do
    let(:buildpack_name) { 'ruby' }

    it 'will not write credentials to the app droplet' do
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

  context 'the Java buildpack', language: 'java' do
    let(:buildpack_name) { 'java' }

    it 'will not write credentials to the app droplet' do
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

  context 'the .NET Core buildpack', language: 'dotnet-core' do
    let(:buildpack_name) { 'dotnet-core' }

    it 'will not write credentials to the app droplet' do
      manifest     = parsed_manifest(buildpack: buildpack_name)
      dotnet_version = manifest['dependencies'].find{ |d| d['name'] == 'dotnet' }['version']

      runtime_version = get_runtime_version(dotnet_version: dotnet_version)

      template = DotnetCoreTemplateApp.new(dotnet_version, runtime_version)
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
end
