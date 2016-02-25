require 'spec_helper'
require 'bcrypt'

RSpec.shared_examples :a_deploy_of_python_app_to_cf do |python_version, stack|
  context "with Python version #{python_version}" do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      template = PythonTemplateApp.new(python_version)
      template.generate!

      @app = Machete.deploy_app(
        template.path,
        name: template.name,
        buildpack: 'python-brat-buildpack',
        stack: stack
      )
    end

    after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

    it 'runs a simple webserver', version: python_version do
      expect(@app).to be_running
      expect(@app).to have_logged /Installing.*python-#{python_version}/

      2.times do
        browser.visit_path('/')
        expect(browser).to have_body('Hello, World')
      end
    end

    it 'encrypts with bcrypt', version: python_version do
      2.times do
        browser.visit_path('/bcrypt')
        crypted_text = BCrypt::Password.new(browser.body)
        expect(crypted_text).to eq 'Hello, bcrypt'
      end
    end

    it 'supports postgres by raising a no connection error', version: python_version do
      2.times do
        browser.visit_path '/pg'
        expect(browser).to have_body 'could not connect to server: No such file or directory'
      end
    end

    it 'supports mysql by raising a no connection error', version: python_version do
      2.times do
        browser.visit_path '/mysql'
        expect(browser).to have_body "Can't connect to local MySQL server through socket '/var/run/mysqld/mysqld.sock'"
      end
    end

    it 'supports loading and running the hiredis lib', version: python_version do
      2.times do
        browser.visit_path('/redis')
        expect(browser).to have_body 'Hello'
      end
    end
  end
end

describe 'For all supported Python versions', language: 'python' do
  before(:all) { install_buildpack(buildpack: 'python') }
  after(:all) { cleanup_buildpack(buildpack: 'python') }

  def self.dependencies
    parsed_manifest(buildpack: 'python')
      .fetch('dependencies')
  end

  ['cflinuxfs2'].each do |stack|
    context "on the #{stack} stack", stack: stack do
      dependencies.select { |d| d['name'] == 'python' && d['cf_stacks'].include?(stack) }.each do |dependency|
        it_behaves_like :a_deploy_of_python_app_to_cf, dependency['version'], stack
      end
    end
  end
end
