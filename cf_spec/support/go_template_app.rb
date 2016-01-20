class GoTemplateApp
  attr_reader :go_version

  def initialize(go_version)
    @go_version = go_version
  end

  def path
    Shellwords.shellescape("go/tmp/#{go_version}/src/simple_brats")
  end

  def name
    @name ||= "simple-go-#{Time.now.to_i}"
  end

  def generate!
    generate_app('simple_brats', go_version)
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

  def evaluate_erb(file_path, our_binding)
    template = File.read(file_path)
    f = File.open(file_path, 'w')
    f << ERB.new(template).result(our_binding)
    f.close
  end
end
