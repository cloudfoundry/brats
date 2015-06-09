require 'spec_helper'

describe 'For all supported Go versions' do
  before(:all) { install_buildpack(buildpack: 'go') }
  after(:all) { cleanup_buildpack(buildpack: 'go') }

  def self.dependencies
    parsed_manifest(buildpack: 'go').fetch('dependencies')
  end

  def self.create_test_for(test_name, options={})
    options[:engine_version] ||= options[:version]

    context "with #{test_name}" do
      let(:version) { options[:version] }
      let(:app) do
        Machete.deploy_app(
          "go/tmp/#{version}/src/simple_brats",
          name: "simple-go-#{Time.now.to_i}",
          buildpack: 'go-brat-buildpack',
          stack: stack
        )
      end
      let(:browser) { Machete::Browser.new(app) }

      after { Machete::CF::DeleteApp.new.execute(app) }

      it "runs a simple webserver", version: options[:version] do
        generate_app('simple_brats', version)
        assert_correct_version_installed(version)

        assert_root_contains('Hello, World')
      end
    end
  end

  context 'On lucid64 stack', stack: 'lucid64' do
    let(:stack) { 'lucid64' }

    dependencies.each do |dependency|
      create_test_for("#{dependency['name']} #{dependency['version']}", version: dependency['version'])
    end
  end

  context 'On cflinuxfs2 stack', stack: 'cflinuxfs2' do
    let(:stack) { 'cflinuxfs2' }

    dependencies.each do |dependency|
      create_test_for("#{dependency['name']} #{dependency['version']}", version: dependency['version'])
    end
  end

  def generate_app(app_name, version)
    origin_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'go', 'src', app_name)
		copied_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'go', 'tmp', version.to_s, 'src', app_name)
    FileUtils.rm_rf(copied_template_path)
    FileUtils.mkdir_p(File.dirname(copied_template_path))
    FileUtils.cp_r(origin_template_path, copied_template_path)

    ['Godeps.json'].each do |file|
      evaluate_erb(File.join(copied_template_path, 'Godeps', file), binding)
    end
  end

  def assert_correct_version_installed(version)
    expect(app).to be_running(120)
    expect(app).to have_logged "Installing go#{version}"
  end


  def assert_root_contains(text)
    2.times do
      browser.visit_path('/')
      expect(browser).to have_body(text)
    end
  end

  def evaluate_erb(file_path, our_binding)
    template = File.read(file_path)
    f = File.open(file_path, 'w')
    f << ERB.new(template).result(our_binding)
    f.close
  end
end
