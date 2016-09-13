class NodeJSTemplateApp
  attr_reader :nodejs_version, :full_path

  def initialize(nodejs_version)
    @nodejs_version = nodejs_version
  end

  def path
    Shellwords.shellescape("nodejs/tmp/#{nodejs_version}/simple_brats")
  end

  def name
    @name ||= "simple-nodejs-#{Time.now.to_i}"
  end

  def generate!
    origin_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'nodejs', 'simple_brats')
    copied_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'nodejs', 'tmp', nodejs_version.to_s, 'simple_brats')
    @full_path = File.expand_path(copied_template_path)
    FileUtils.rm_rf(copied_template_path)
    FileUtils.mkdir_p(File.dirname(copied_template_path))
    FileUtils.cp_r(origin_template_path, copied_template_path)

    package = {
      'name' => 'node_web_app',
      'version' => '0.0.0',
      'description' => 'hello, world',
      'main' => 'server.js',
      'engines' => {
        'node' => nodejs_version
      },
      'dependencies' => {
        'bcrypt' => '0.8.6',
        'bson-ext' => '0.1.13'
      }
    }
    File.write(
      File.join(copied_template_path, 'package.json'),
      JSON.generate(package)
    )
  end
end
