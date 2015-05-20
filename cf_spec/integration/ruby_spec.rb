require 'spec_helper'

describe 'For all supported Ruby versions' do
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
          buildpack: 'ruby-brat-buildpack'
        )
      end

      after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

      it "runs a simple webserver", version: options[:version] do
        assert_ruby_version_installed(ruby_version)

        unless engine == 'ruby'
          assert_ruby_version_and_engine_installed(ruby_version, engine, engine_version)
        end

        assert_root_contains('Hello, World')
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
    end
  end

  context 'On lucid64 stack' do
    before { ENV['CF_STACK'] = 'lucid64' }

    dependencies.select do |dependency|
      dependency['cf_stacks'].include?('lucid64')
    end.each do |dependency|
      if dependency['name'] == 'ruby'
        version = dependency['version']
        create_test_for("Ruby #{version}", engine: 'ruby', version: version)
      elsif dependency['name'] == 'jruby'
        match_data = dependency['version'].match(/ruby-(\d+\.\d+\.\d+)-jruby-(\d+\.\d+\.\d+(?:\.\d\.pre\d)?)/)
        ruby_version = match_data[1]
        engine_version = match_data[2]
        create_test_for("JRuby #{engine_version} Ruby #{ruby_version}",
                          engine: 'jruby',
                          engine_version: engine_version,
                          version: ruby_version)
      end
    end
  end

  context 'On cflinuxfs2 stack' do
    before { ENV['CF_STACK'] = 'cflinuxfs2' }

    dependencies.select do |dependency|
      dependency['cf_stacks'].include?('cflinuxfs2')
    end.each do |dependency|
      if dependency['name'] == 'ruby'
        version = dependency['version']
        create_test_for("Ruby #{version}", engine: 'ruby', version: version)
      elsif dependency['name'] == 'jruby'
        match_data = dependency['version'].match(/ruby-(\d+\.\d+\.\d+)-jruby-(\d+\.\d+\.\d+(?:\.\d\.pre\d)?)/)
        ruby_version = match_data[1]
        engine_version = match_data[2]
        create_test_for("JRuby #{engine_version} Ruby #{ruby_version}",
                          engine: 'jruby',
                          engine_version: engine_version,
                          version: ruby_version)
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

  def assert_ruby_version_installed(ruby_version)
    expect(@app).to be_running
    expect(@app).to have_logged "Using Ruby version: ruby-#{ruby_version}"
  end

  def assert_ruby_version_and_engine_installed(ruby_version, engine, engine_version)
    expect(@app).to be_running
    expect(@app).to have_logged "Using Ruby version: ruby-#{ruby_version}-#{engine}-#{engine_version}"
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
