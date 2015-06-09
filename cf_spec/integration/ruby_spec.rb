require 'spec_helper'
require 'bcrypt'

describe 'For all supported Ruby versions' do
  before(:all) { install_buildpack(buildpack: 'ruby') }
  after(:all) { cleanup_buildpack(buildpack: 'ruby') }

  def self.dependencies
    parsed_manifest(buildpack: 'ruby')
      .fetch('dependencies')
  end

  def self.create_test_for(test_name, options={})
    options[:engine_version] ||= options[:version]

    context "with #{test_name}" do
      let(:ruby_version) { options[:version] }
      let(:engine) { options[:engine] }
      let(:engine_version) { options[:engine_version] }
      let(:browser) { Machete::Browser.new(@app) }

      before(:all) do
        generate_app('simple_brats', options[:version], options[:engine], options[:engine_version])

        @app = Machete.deploy_app(
          "rubies/tmp/#{options[:version]}/simple_brats",
          name: "simple-ruby-#{Time.now.to_i}",
          buildpack: 'ruby-brat-buildpack',
          stack: @stack
        )
      end

      after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

      it "installs the correct version of Ruby", version: options[:version] do
        expect(@app).to be_running
        expect(@app).to have_logged "Using Ruby version: ruby-#{ruby_version}"
      end

      it "runs a simple webserver", version: options[:version] do
        2.times do
          browser.visit_path('/')
          expect(browser).to have_body('Hello, World')
        end
      end

      it "parses XML with nokogiri", version: options[:version] do
        2.times do
          browser.visit_path('/nokogiri')
          expect(browser).to have_body('Hello, World')
        end
      end

      it "supports EventMachine", version: options[:version] do
        2.times do
          browser.visit_path('/em')
          expect(browser).to have_body('Hello, EventMachine')
        end
      end

      it "encrypts with bcrypt", version: options[:version] do
        2.times do
          browser.visit_path('/bcrypt')
          crypted_text = BCrypt::Password.new(browser.body)
          expect(crypted_text).to eq 'Hello, bcrypt'
        end
      end

      it "supports bson", version: options[:version] do
        2.times do
          browser.visit_path('/bson')
          expect(browser).to have_body('00040000')
        end
      end

      it "supports postgres", version: options[:version] do
        2.times do
          browser.visit_path('/pg')

          expect(browser).to have_body('could not connect to server: No such file or directory')
        end
      end

      it "supports mysql", version: options[:version] do
        2.times do
          browser.visit_path('/mysql')

          expect(browser).to have_body("Unknown MySQL server host 'testing'")
        end
      end
    end
  end

  context 'On lucid64 stack', stack: 'lucid64' do
    before { ENV['CF_STACK'] = 'lucid64' }

    dependencies.select do |dependency|
      dependency['cf_stacks'].include?('lucid64')
    end.each do |dependency|
      if dependency['name'] == 'ruby'
        version = dependency['version']
        create_test_for("Ruby #{version}", engine: 'ruby', version: version)
      end
    end
  end

  context 'On cflinuxfs2 stack', stack: 'cflinuxfs2' do
    before { ENV['CF_STACK'] = 'cflinuxfs2' }

    dependencies.select do |dependency|
      dependency['cf_stacks'].include?('cflinuxfs2')
    end.each do |dependency|
      if dependency['name'] == 'ruby'
        version = dependency['version']
        create_test_for("Ruby #{version}", engine: 'ruby', version: version)
      end
    end
  end

  def generate_app(app_name, ruby_version, engine, engine_version)
    origin_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'rubies', app_name)
    copied_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'rubies', 'tmp', ruby_version, app_name)
    FileUtils.rm_rf(copied_template_path)
    FileUtils.mkdir_p(File.dirname(copied_template_path))
    FileUtils.cp_r(origin_template_path, copied_template_path)

    ['Gemfile', '.jrubyrc', 'Gemfile.lock'].each do |file|
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
