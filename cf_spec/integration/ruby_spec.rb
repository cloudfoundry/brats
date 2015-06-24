require 'spec_helper'
require 'bcrypt'


RSpec.shared_examples :a_deploy_of_ruby_app_to_cf do |ruby_version, stack|
  context "with Ruby version #{ruby_version}", version: ruby_version do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      generate_app('simple_brats', ruby_version, 'ruby', ruby_version)

      @app = Machete.deploy_app(
        "ruby/tmp/#{ruby_version}/simple_brats",
        name: "simple-jruby-#{Time.now.to_i}",
        buildpack: 'ruby-brat-buildpack',
        stack: stack
      )
    end

    after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

    it "installs the correct version of Ruby" do
      expect(@app).to be_running
      expect(@app).to have_logged "Using Ruby version: ruby-#{ruby_version}"
    end

    it "runs a simple webserver" do
      2.times do
        browser.visit_path('/')
        expect(browser).to have_body('Hello, World')
      end
    end

    it "parses XML with nokogiri" do
      2.times do
        browser.visit_path('/nokogiri')
        expect(browser).to have_body('Hello, World')
      end
    end

    it "supports EventMachine" do
      2.times do
        browser.visit_path('/em')
        expect(browser).to have_body('Hello, EventMachine')
      end
    end

    it "encrypts with bcrypt" do
      2.times do
        browser.visit_path('/bcrypt')
        crypted_text = BCrypt::Password.new(browser.body)
        expect(crypted_text).to eq 'Hello, bcrypt'
      end
    end

    it "supports bson" do
      2.times do
        browser.visit_path('/bson')
        expect(browser).to have_body('00040000')
      end
    end

    it "supports postgres" do
      2.times do
        browser.visit_path('/pg')

        expect(browser).to have_body('could not connect to server: No such file or directory')
      end
    end

    it "supports mysql" do
      2.times do
        browser.visit_path('/mysql')

        expect(browser).to have_body("Unknown MySQL server host 'testing'")
      end
    end

    it "supports rmagick" do
      2.times do
        browser.visit_path("/rmagick")

        expect(browser).to have_body("width 1484")
        expect(browser).to have_body("height 1066")
      end
    end
  end
end

describe 'For all supported Ruby versions' do
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

    def generate_app(app_name, ruby_version, engine, engine_version)
      origin_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'ruby', app_name)
      copied_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'ruby', 'tmp', ruby_version, app_name)
      FileUtils.rm_rf(copied_template_path)
      FileUtils.mkdir_p(File.dirname(copied_template_path))
      FileUtils.cp_r(origin_template_path, copied_template_path)

      ['Gemfile'].each do |file|
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
end

