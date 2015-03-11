require_relative '../spec_helper'

describe 'For all supported Ruby versions' do
  def self.create_test_for(test_name, options={})
    options[:engine_version] ||= options[:version]

    context "with #{test_name}" do
      let(:ruby_version) { options[:version] }
      let(:engine) { options[:engine] }
      let(:engine_version) { options[:engine_version] }
      let(:app) { Machete.deploy_app("rubies/tmp/#{ruby_version}/simple") }
      let(:browser) { Machete::Browser.new(app) }

      specify do
        generate_app('simple', ruby_version, engine, engine_version)
        assert_ruby_version_installed(ruby_version)

        unless engine == 'ruby'
          assert_ruby_version_and_engine_installed(ruby_version, engine, engine_version)
        end

        assert_root_contains('Hello, World')
        assert_offline_mode_has_no_traffic
      end
    end
  end

  context 'On lucid64 stack' do
    before { ENV['CF_STACK'] = 'lucid64' }

    create_test_for('Ruby 1.8.7', engine: 'ruby', version: '1.8.7')
    create_test_for('Ruby 1.9.2', engine: 'ruby', version: '1.9.2')
    create_test_for('Ruby 1.9.3', engine: 'ruby', version: '1.9.3')
    create_test_for('Ruby 2.0.0', engine: 'ruby', version: '2.0.0')
    create_test_for('Ruby 2.1.0', engine: 'ruby', version: '2.1.0')
    create_test_for('Ruby 2.1.1', engine: 'ruby', version: '2.1.1')
    create_test_for('Ruby 2.1.2', engine: 'ruby', version: '2.1.2')
    create_test_for('Ruby 2.1.3', engine: 'ruby', version: '2.1.3')
    create_test_for('Ruby 2.1.4', engine: 'ruby', version: '2.1.4')
    create_test_for('Ruby 2.1.5', engine: 'ruby', version: '2.1.5')
    create_test_for('Ruby 2.2.0', engine: 'ruby', version: '2.2.0')

    create_test_for('JRuby 1.7.1 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.1', version: '1.8.7')
    create_test_for('JRuby 1.7.1 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.1', version: '1.9.3')

    create_test_for('JRuby 1.7.2 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.2', version: '1.8.7')
    create_test_for('JRuby 1.7.2 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.2', version: '1.9.3')

    create_test_for('JRuby 1.7.3 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.3', version: '1.8.7')
    create_test_for('JRuby 1.7.3 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.3', version: '1.9.3')

    create_test_for('JRuby 1.7.4 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.4', version: '1.8.7')
    create_test_for('JRuby 1.7.4 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.4', version: '1.9.3')

    create_test_for('JRuby 1.7.5 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.5', version: '1.8.7')
    create_test_for('JRuby 1.7.5 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.5', version: '1.9.3')
    create_test_for('JRuby 1.7.5 Ruby 2.0.0', engine: 'jruby', engine_version: '1.7.5', version: '2.0.0')

    create_test_for('JRuby 1.7.6 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.6', version: '1.8.7')
    create_test_for('JRuby 1.7.6 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.6', version: '1.9.3')
    create_test_for('JRuby 1.7.6 Ruby 2.0.0', engine: 'jruby', engine_version: '1.7.6', version: '2.0.0')

    create_test_for('JRuby 1.7.8 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.8', version: '1.8.7')
    create_test_for('JRuby 1.7.8 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.8', version: '1.9.3')
    create_test_for('JRuby 1.7.8 Ruby 2.0.0', engine: 'jruby', engine_version: '1.7.8', version: '2.0.0')

    create_test_for('JRuby 1.7.9 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.9', version: '1.8.7')
    create_test_for('JRuby 1.7.9 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.9', version: '1.9.3')
    create_test_for('JRuby 1.7.9 Ruby 2.0.0', engine: 'jruby', engine_version: '1.7.9', version: '2.0.0')

    create_test_for('JRuby 1.7.10 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.10', version: '1.8.7')
    create_test_for('JRuby 1.7.10 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.10', version: '1.9.3')
    create_test_for('JRuby 1.7.10 Ruby 2.0.0', engine: 'jruby', engine_version: '1.7.10', version: '2.0.0')

    create_test_for('JRuby 1.7.11 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.11', version: '1.8.7')
    create_test_for('JRuby 1.7.11 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.11', version: '1.9.3')
    create_test_for('JRuby 1.7.11 Ruby 2.0.0', engine: 'jruby', engine_version: '1.7.11', version: '2.0.0')
  end

  context 'On cflinuxfs2 stack' do
    before { ENV['CF_STACK'] = 'cflinuxfs2' }

    create_test_for('Ruby 1.9.2', engine: 'ruby', version: '1.9.2')
    create_test_for('Ruby 1.9.3', engine: 'ruby', version: '1.9.3')
    create_test_for('Ruby 2.0.0', engine: 'ruby', version: '2.0.0')
    create_test_for('Ruby 2.1.2', engine: 'ruby', version: '2.1.2')
    create_test_for('Ruby 2.1.3', engine: 'ruby', version: '2.1.3')
    create_test_for('Ruby 2.1.4', engine: 'ruby', version: '2.1.4')
    create_test_for('Ruby 2.1.5', engine: 'ruby', version: '2.1.5')
    create_test_for('Ruby 2.2.0', engine: 'ruby', version: '2.2.0')

    create_test_for('JRuby 1.7.1 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.1', version: '1.8.7')
    create_test_for('JRuby 1.7.1 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.1', version: '1.9.3')

    create_test_for('JRuby 1.7.2 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.2', version: '1.8.7')
    create_test_for('JRuby 1.7.2 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.2', version: '1.9.3')

    create_test_for('JRuby 1.7.3 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.3', version: '1.8.7')
    create_test_for('JRuby 1.7.3 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.3', version: '1.9.3')

    create_test_for('JRuby 1.7.4 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.4', version: '1.8.7')
    create_test_for('JRuby 1.7.4 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.4', version: '1.9.3')

    create_test_for('JRuby 1.7.5 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.5', version: '1.8.7')
    create_test_for('JRuby 1.7.5 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.5', version: '1.9.3')
    create_test_for('JRuby 1.7.5 Ruby 2.0.0', engine: 'jruby', engine_version: '1.7.5', version: '2.0.0')

    create_test_for('JRuby 1.7.6 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.6', version: '1.8.7')
    create_test_for('JRuby 1.7.6 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.6', version: '1.9.3')
    create_test_for('JRuby 1.7.6 Ruby 2.0.0', engine: 'jruby', engine_version: '1.7.6', version: '2.0.0')

    create_test_for('JRuby 1.7.8 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.8', version: '1.8.7')
    create_test_for('JRuby 1.7.8 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.8', version: '1.9.3')
    create_test_for('JRuby 1.7.8 Ruby 2.0.0', engine: 'jruby', engine_version: '1.7.8', version: '2.0.0')

    create_test_for('JRuby 1.7.9 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.9', version: '1.8.7')
    create_test_for('JRuby 1.7.9 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.9', version: '1.9.3')
    create_test_for('JRuby 1.7.9 Ruby 2.0.0', engine: 'jruby', engine_version: '1.7.9', version: '2.0.0')

    create_test_for('JRuby 1.7.10 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.10', version: '1.8.7')
    create_test_for('JRuby 1.7.10 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.10', version: '1.9.3')
    create_test_for('JRuby 1.7.10 Ruby 2.0.0', engine: 'jruby', engine_version: '1.7.10', version: '2.0.0')

    create_test_for('JRuby 1.7.11 Ruby 1.8.7', engine: 'jruby', engine_version: '1.7.11', version: '1.8.7')
    create_test_for('JRuby 1.7.11 Ruby 1.9.3', engine: 'jruby', engine_version: '1.7.11', version: '1.9.3')
    create_test_for('JRuby 1.7.11 Ruby 2.0.0', engine: 'jruby', engine_version: '1.7.11', version: '2.0.0')
  end

  def assert_offline_mode_has_no_traffic
    expect(app.host).not_to have_internet_traffic if Machete::BuildpackMode.offline?
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

  def assert_ruby_version_installed(ruby_version)
    expect(app).to be_running
    expect(app).to have_logged "Using Ruby version: ruby-#{ruby_version}"
  end

  def assert_ruby_version_and_engine_installed(ruby_version, engine, engine_version)
    expect(app).to be_running
    expect(app).to have_logged "Using Ruby version: ruby-#{ruby_version}-#{engine}-#{engine_version}"
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
