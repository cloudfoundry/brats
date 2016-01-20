class RubyTemplateApp
  attr_reader :ruby_version

  def initialize(ruby_version)
    @ruby_version = ruby_version
  end

  def path
    Shellwords.shellescape("ruby/tmp/#{ruby_version}/simple_brats")
  end

  def name
    @name ||= "simple-ruby-#{Time.now.to_i}"
  end

  def generate!
    generate_app('simple_brats', ruby_version, 'ruby', ruby_version)
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
