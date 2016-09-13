class JRubyTemplateApp
  attr_reader :ruby_version, :engine_version, :full_path

  def initialize(ruby_version, engine_version)
    @ruby_version = ruby_version
    @engine_version = engine_version
  end

  def path
    Shellwords.shellescape("jruby/tmp/#{ruby_version}/simple_brats")
  end

  def name
    @name ||= "simple-jruby-#{Time.now.to_i}"
  end

  def generate!
    generate_app('simple_brats', ruby_version, 'jruby', engine_version)
  end

  def generate_app(app_name, ruby_version, engine, engine_version)
    origin_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'jruby', app_name)
    copied_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'jruby', 'tmp', ruby_version, app_name)
    @full_path = File.expand_path(copied_template_path)
    FileUtils.rm_rf(copied_template_path)
    FileUtils.mkdir_p(File.dirname(copied_template_path))
    FileUtils.cp_r(origin_template_path, copied_template_path)

    ['Gemfile','.jrubyrc'].each do |file|
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
