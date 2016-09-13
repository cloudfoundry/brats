class StaticfileTemplateApp
  attr_reader :full_path

  def path
    "staticfile/tmp/simple_brats"
  end

  def name
    @name ||= "simple-staticfile-#{Time.now.to_i}"
  end

  def generate!
    origin_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'staticfile', 'simple_brats')
    copied_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'staticfile', 'tmp', 'simple_brats')
    @full_path = File.expand_path(copied_template_path)
    FileUtils.rm_rf(copied_template_path)
    FileUtils.mkdir_p(File.dirname(copied_template_path))
    FileUtils.cp_r(origin_template_path, copied_template_path)
  end
end
