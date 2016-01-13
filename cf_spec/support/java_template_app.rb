class JavaTemplateApp
  def path
    'java/sample.war'
  end

  def name
    @name ||= "simple-java-#{Time.now.to_i}"
  end
end
