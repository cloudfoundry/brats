class BinaryTemplateApp
  attr_reader :full_path

  def path
    "binary/tmp/simple_brats"
  end

  def name
    @name ||= "simple-binary-#{Time.now.to_i}"
  end

  def generate!
    origin_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'binary', 'simple_brats')
    copied_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'binary', 'tmp', 'simple_brats')
    @full_path = File.expand_path(copied_template_path)
    FileUtils.rm_rf(copied_template_path)
    FileUtils.mkdir_p(File.dirname(copied_template_path))
    FileUtils.cp_r(origin_template_path, copied_template_path)
  end
end
