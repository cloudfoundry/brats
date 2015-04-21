require 'bundler/setup'
require 'machete'
require 'machete/matchers'
require 'json'
require 'yaml'

`mkdir -p log`
Machete.logger = Machete::Logger.new("log/integration.log")

def parsed_manifest(buildpack:)
  buildpack_path = File.join(File.dirname(__FILE__), '..', 'tmp', "#{buildpack}-buildpack")
  manifest_path = File.join(buildpack_path, 'manifest.yml')

  raise "Buildpack has not been checkedout in #{buildpack_path}" unless File.exist?(manifest_path)

  YAML.load_file(manifest_path)
end
