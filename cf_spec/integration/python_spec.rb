require_relative '../spec_helper'
require 'yaml'

describe 'For all supported Python versions' do
  def self.create_test_for(test_name, options={})
    options[:engine_version] ||= options[:version]

    context "with #{test_name}" do
      let(:app_name) { 'python' }
      let(:version) { options[:version] }
      let(:app) { Machete.deploy_app("python/tmp/#{version}/simple", buildpack: 'python-brat-buildpack') }
      let(:browser) { Machete::Browser.new(app) }

      specify do
        generate_app('simple', version)
        assert_correct_version_installed(version)

        assert_root_contains('Hello, World')
        assert_offline_mode_has_no_traffic
      end
    end
  end

  dependencies = YAML::load(open('https://raw.githubusercontent.com/cloudfoundry/python-buildpack/master/manifest.yml').read)['dependencies']

  context 'On lucid64 stack' do
    before { ENV['CF_STACK'] = 'lucid64' }

    dependencies.each do |dependency|
      if dependency['name'] == 'python' && dependency['cf_stacks'].include?('lucid64')
        create_test_for("#{dependency['name']} #{dependency['version']}", version: dependency['version'])
      end
    end
  end

  context 'On cflinuxfs2 stack' do
    before { ENV['CF_STACK'] = 'cflinuxfs2' }

    dependencies.each do |dependency|
      if dependency['name'] == 'python' && dependency['cf_stacks'].include?('cflinuxfs2')
        create_test_for("#{dependency['name']} #{dependency['version']}", version: dependency['version'])
      end
    end
  end


  def assert_offline_mode_has_no_traffic
    expect(app.host).not_to have_internet_traffic if Machete::BuildpackMode.offline?
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

  def assert_correct_version_installed(version)
    expect(app).to be_running
    expect(app).to have_logged "Installing runtime (python-#{version})"
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
