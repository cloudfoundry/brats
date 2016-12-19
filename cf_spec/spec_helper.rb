require 'bundler/setup'
require 'fileutils'
require 'json'
require 'machete'
require 'machete/matchers'
require 'open-uri'
require 'yaml'
require 'shellwords'

`mkdir -p log`
Machete.logger = Machete::Logger.new('log/integration.log')

BRATS_BRANCH = ENV['BRATS_BRANCH'] || 'master'

def is_current_user_language_tag?(language)
  RSpec.configure do |config|
    config.color = true
    config.tty = true

    language == config.filter.rules[:language]
  end
end

def parsed_manifest(buildpack:, branch: BRATS_BRANCH)
  manifest_url = "https://raw.githubusercontent.com/cloudfoundry/#{buildpack}-buildpack/#{branch}/manifest.yml"
  YAML.load(open(manifest_url))
end

def sdk_msbuild?(sdk_version:, branch: BRATS_BRANCH)
  sdk_versions_url = "https://raw.githubusercontent.com/cloudfoundry/dotnet-core-buildpack/#{branch}/dotnet-sdk-tools.yml"
  YAML.load(open(sdk_versions_url))['msbuild'].include? sdk_version
end

def dependency_versions_in_manifest(buildpack, dependency, stack)
  dependencies = parsed_manifest(buildpack: buildpack).fetch('dependencies')
  dependencies.select { |d| d['name'] == dependency && d['cf_stacks'].include?(stack) }.map {|dep| dep['version']}
end

def skip_if_no_dot_profile_support_on_targeted_cf
  minimum_acceptable_cf_api_version = '2.57.0'
  skip_reason = ".profile script functionality not supported before CF API version #{minimum_acceptable_cf_api_version}"
  Machete::RSpecHelpers.skip_if_cf_api_below(version: minimum_acceptable_cf_api_version, reason: skip_reason)
end

def add_dot_profile_script_to_app(template_path)
  profile_path = File.join(template_path, '.profile')
  File.open(profile_path, 'w') do |file|
    file.write( <<~BASHCODE
                   #!/usr/bin/env bash

                   echo PROFILE_SCRIPT_IS_PRESENT_AND_RAN

                   BASHCODE
)
    file.chmod(0755)
  end
end

def deploy_app(template:, stack:, buildpack:)
  Machete.deploy_app(
    template.path,
    name: template.name,
    buildpack: buildpack,
    stack: stack
  )
end

def bump_buildpack_version(buildpack:)
  FileUtils.mkdir_p('tmp')
  File.write("tmp/#{buildpack}-buildpack/VERSION", '99.99.99')
  Bundler.with_clean_env do
    system(<<-EOF)
           cd tmp/#{buildpack}-buildpack
           export BUNDLE_GEMFILE=cf.Gemfile
           bundle install
           bundle exec buildpack-packager --cached
           cf update-buildpack #{buildpack}-brat-buildpack -p #{buildpack}_buildpack-cached-v99.99.99.zip -i 1 --enable
           echo "\n\nBumping version of #{buildpack}-brat-buildpack\n\n"
    EOF
  end
end

def install_buildpack(buildpack:, branch: BRATS_BRANCH, position: 100)
  FileUtils.mkdir_p('tmp')
  Bundler.with_clean_env do
    system(<<-EOF)
      set -e
      GITHUB_URL=https://github.com/cloudfoundry/#{buildpack}-buildpack
      git clone -q -b #{branch} --depth 1 --recursive "$GITHUB_URL" tmp/#{buildpack}-buildpack
      cd tmp/#{buildpack}-buildpack
      export BUNDLE_GEMFILE=cf.Gemfile
      bundle install
      bundle exec buildpack-packager --cached || bundle exec buildpack-packager cached
      cf delete-buildpack #{buildpack}-brat-buildpack -f
      cf create-buildpack #{buildpack}-brat-buildpack $(ls *_buildpack-cached*.zip | head -n 1) #{position} --enable

      echo "\n\nRunning Brats tests on: $GITHUB_URL\nUsing git branch: #{branch}\nLatest $(git log -1)\n\n"
    EOF
  end
end

def install_buildpack_with_uri_credentials(buildpack:, branch: BRATS_BRANCH, position: 100, buildpack_caching: :uncached)
  available_packager_options = { cached: 'cached', uncached: 'uncached' }
  packager_option = available_packager_options[buildpack_caching]

  FileUtils.mkdir_p('tmp')
  Bundler.with_clean_env do
    system(<<-EOF)
      set -e
      GITHUB_URL=https://github.com/cloudfoundry/#{buildpack}-buildpack
      git clone -q -b #{branch} --depth 1 --recursive "$GITHUB_URL" tmp/#{buildpack}-buildpack
    EOF

    manifest_path = "./tmp/#{buildpack}-buildpack/manifest.yml"
    put_credentials_in_uris_in_manifest(manifest_path)

    system(<<-EOF)
      set -e
      cd tmp/#{buildpack}-buildpack
      export BUNDLE_GEMFILE=cf.Gemfile
      bundle install
      bundle exec buildpack-packager --#{packager_option} || bundle exec buildpack-packager #{packager_option}
      cf delete-buildpack #{buildpack}-brat-buildpack -f
      cf create-buildpack #{buildpack}-brat-buildpack $(ls *_buildpack*.zip | head -n 1) #{position} --enable

      echo "\n\nRunning Brats tests on simulated buildpack with credentials in uri: $GITHUB_URL\nUsing git branch: #{branch}\nLatest $(git log -1)\n\n"
    EOF
  end
end

def put_credentials_in_uris_in_manifest(manifest_path)
  manifest_hash = YAML.load_file(manifest_path)

  dependencies = manifest_hash["dependencies"]

  dependencies.each do |dep|
    uri = URI(dep["uri"])
    uri.user = 'login'
    uri.password = 'password'
    dep["uri"] = uri.to_s
  end

  manifest_hash["dependencies"] = dependencies

  File.open(manifest_path, 'w') {|f| f.write(manifest_hash.to_yaml) }
end

def install_java_buildpack(branch: BRATS_BRANCH, position: 100)
  FileUtils.mkdir_p('tmp')
  Bundler.with_clean_env do
    system(<<-EOF)
      set -e
      GITHUB_URL=https://github.com/cloudfoundry/java-buildpack
      git clone -q -b #{branch} --depth 1 --recursive "$GITHUB_URL" tmp/java-buildpack
      cd tmp/java-buildpack
      bundle install
      bundle exec rake package OFFLINE=true PINNED=true
      cf delete-buildpack java-brat-buildpack -f
      cf create-buildpack java-brat-buildpack $(ls build/java-buildpack-offline-*.zip | head -n 1) #{position} --enable

      echo "\n\nRunning Brats tests on: $GITHUB_URL\nUsing git branch: #{branch}\nLatest $(git log -1)\n\n"
    EOF
  end

end

def cleanup_buildpack(buildpack:)
  `
    rm -Rf tmp/#{buildpack}-buildpack
    cf delete-buildpack #{buildpack}-brat-buildpack -f
  `
end

Dir['./cf_spec/support/**/*.rb'].each { |f| require f }
