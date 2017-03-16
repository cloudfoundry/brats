class JavaTemplateApp
  def path
    'java/sample.war'
  end

  def manifest
    File.join(File.dirname(__FILE__), '..', '..', 'cf_spec/fixtures/java/manifest.yml')
  end

  def name
    @name ||= "simple-java-#{Time.now.to_i}"
  end
end
