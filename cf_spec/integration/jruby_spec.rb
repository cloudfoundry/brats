require 'spec_helper'
require 'bcrypt'

RSpec.shared_examples :a_deploy_of_jruby_app_to_cf do |ruby_version, jruby_version, stack|
  context "with JRuby version #{jruby_version} and Ruby version #{ruby_version}", version: ruby_version do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      generate_app('simple_brats', ruby_version, 'jruby', jruby_version)

      @app = Machete.deploy_app(
        "jruby/tmp/#{ruby_version}/simple_brats",
        name: "simple-jruby-#{Time.now.to_i}",
        buildpack: 'ruby-brat-buildpack',
        stack: stack
      )
    end

    after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

    it 'installs the correct version of JRuby' do
      expect(@app).to be_running
      expect(@app).to have_logged "Using Ruby version: ruby-#{ruby_version}-jruby-#{jruby_version}"
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

        expect(browser).to have_body('The connection attempt failed.')
      end
    end

    it 'supports mysql' do
      2.times do
        browser.visit_path('/mysql')

        expect(browser).to have_body('Communications link failure')
      end
    end
  end

  def generate_app(app_name, ruby_version, engine, engine_version)
    origin_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'jruby', app_name)
    copied_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'jruby', 'tmp', ruby_version, app_name)
    FileUtils.rm_rf(copied_template_path)
    FileUtils.mkdir_p(File.dirname(copied_template_path))
    FileUtils.cp_r(origin_template_path, copied_template_path)

    ['Gemfile', '.jrubyrc'].each do |file|
      evaluate_erb(File.join(copied_template_path, file), binding)
    end
  end

  def evaluate_erb(file_path, our_binding)
    template = File.read(file_path)
    f = File.open(file_path, 'w')
    f << ERB.new(template).result(our_binding)
    f.close
  end
end

describe 'For all supported JRuby versions', language: 'ruby' do
  before(:all) do
    cleanup_buildpack(buildpack: 'ruby')
    install_buildpack(buildpack: 'ruby')
  end

  def self.dependencies
    parsed_manifest(buildpack: 'ruby')
      .fetch('dependencies')
  end

  ['cflinuxfs2'].each do |stack|
    context "On #{stack} stack", stack: stack do
      dependencies.select do |dependency|
        dependency['cf_stacks'].include?(stack)
      end.each do |dependency|
        next unless dependency['name'] == 'jruby'
        match_data = dependency['version'].match(/ruby-(.*)-jruby-(.*)/)
        ruby_version = match_data[1]
        jruby_version = match_data[2]
        it_behaves_like :a_deploy_of_jruby_app_to_cf, ruby_version, jruby_version, stack
      end
    end
  end
end
