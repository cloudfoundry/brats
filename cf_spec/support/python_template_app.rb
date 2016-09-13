class PythonTemplateApp
  attr_reader :python_version, :full_path

  def initialize(python_version)
    @python_version = python_version
  end

  def path
    Shellwords.shellescape("python/tmp/#{python_version}/simple_brats")
  end

  def name
    @name ||= "simple-python-#{Time.now.to_i}"
  end

  def generate!
    generate_app('simple_brats', python_version)
  end

  def generate_app(app_name, version)
    origin_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'python', app_name)
    copied_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'python', 'tmp', version.to_s, app_name)
    @full_path = File.expand_path(copied_template_path)
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
