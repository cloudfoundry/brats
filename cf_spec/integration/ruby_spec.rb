require 'spec_helper'
require 'bcrypt'

RSpec.shared_examples :a_deploy_of_ruby_app_to_cf do |ruby_version, stack|
  context "with Ruby version #{ruby_version}", version: ruby_version do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      template = RubyTemplateApp.new(ruby_version)
      template.generate!

      @app = Machete.deploy_app(
        template.path,
        name: template.name,
        buildpack: 'ruby-brat-buildpack',
        stack: stack
      )
    end

    after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

    it 'installs the correct version of Ruby' do
      expect(@app).to be_running
      expect(@app).to have_logged "Using Ruby version: ruby-#{ruby_version}"
    end

    it 'runs a simple webserver' do
      2.times do
        browser.visit_path('/')
        expect(browser).to have_body('Hello, World')
      end
    end

    it 'parses XML with nokogiri' do
      2.times do
        browser.visit_path('/nokogiri')
        expect(browser).to have_body('Hello, World')
      end
    end

    it 'supports EventMachine' do
      2.times do
        browser.visit_path('/em')
        expect(browser).to have_body('Hello, EventMachine')
      end
    end

    it 'encrypts with bcrypt' do
      2.times do
        browser.visit_path('/bcrypt')
        crypted_text = BCrypt::Password.new(browser.body)
        expect(crypted_text).to eq 'Hello, bcrypt'
      end
    end

    it 'supports bson' do
      2.times do
        browser.visit_path('/bson')
        expect(browser).to have_body('00040000')
      end
    end

    it 'supports postgres' do
      2.times do
        browser.visit_path('/pg')

        expect(browser).to have_body('could not connect to server: No such file or directory')
      end
    end

    it 'supports mysql' do
      2.times do
        browser.visit_path('/mysql')

        expect(browser).to have_body("Unknown MySQL server host 'testing'")
      end
    end
  end
end

describe 'For all supported Ruby versions', language: 'ruby' do
  before(:all) { install_buildpack(buildpack: 'ruby') }
  after(:all) { cleanup_buildpack(buildpack: 'ruby') }

  def self.dependencies
    parsed_manifest(buildpack: 'ruby')
      .fetch('dependencies')
  end

  ['cflinuxfs2'].each do |stack|
    context "On #{stack} stack", stack: stack do
      dependencies.select do |dependency|
        dependency['cf_stacks'].include?(stack)
      end.each do |dependency|
        if dependency['name'] == 'ruby'
          version = dependency['version']
          it_behaves_like :a_deploy_of_ruby_app_to_cf, version, stack
        end
      end
    end
  end
end
