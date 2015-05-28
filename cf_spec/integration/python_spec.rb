require 'spec_helper'
require 'bcrypt'

RSpec.shared_examples :a_deploy_of_python_app_to_cf do |python_version, stack|
  context "with Python version #{python_version}" do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      generate_app('simple_brats', python_version)

      @app = Machete.deploy_app(
        "python/tmp/#{python_version}/simple_brats",
        name: "simple-python-#{Time.now.to_i}",
        buildpack: 'python-brat-buildpack',
        stack: stack
      )
    end

    after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

    it "runs a simple webserver", version: python_version do
      expect(@app).to be_running
      expect(@app).to have_logged "Installing runtime (python-#{python_version})"

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

  def generate_app(app_name, version)
    origin_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'python', app_name)
		copied_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'python', 'tmp', version.to_s, app_name)
    FileUtils.rm_rf(copied_template_path)
    FileUtils.mkdir_p(File.dirname(copied_template_path))
    FileUtils.cp_r(origin_template_path, copied_template_path)

    ['runtime.txt'].each do |file|
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

describe 'For all supported Python versions' do
  def self.dependencies
    parsed_manifest(buildpack: 'python')
      .fetch('dependencies')
  end

  ['lucid64', 'cflinuxfs2'].each do |stack|
    context "on the #{stack} stack", stack: stack do
      dependencies.select{|d| d['name'] == 'python' && d['cf_stacks'].include?(stack)}.each do |dependency|
        it_behaves_like :a_deploy_of_python_app_to_cf, dependency['version'], stack
      end
    end
  end
end
