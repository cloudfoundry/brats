require 'bundler/setup'
require 'machete'
require 'machete/matchers'
require 'open-uri'
require 'json'
require 'fileutils'
require 'yaml'

`mkdir -p log`
Machete.logger = Machete::Logger.new("log/integration.log")

BRATS_BRANCH = ENV['BRATS_BRANCH'] || 'master'

def parsed_manifest(buildpack:, branch: BRATS_BRANCH)
  manifest_url = "https://raw.githubusercontent.com/cloudfoundry/#{buildpack}-buildpack/#{branch}/manifest.yml"
  YAML.load(open(manifest_url))
end

def install_buildpack(buildpack:, branch: BRATS_BRANCH)
  FileUtils.mkdir_p('tmp')
  Bundler.with_clean_env do
    system(<<-EOF)
      set -e
      GITHUB_URL=https://github.com/cloudfoundry/#{buildpack}-buildpack
      git clone -q -b #{branch} --depth 1 --recursive "$GITHUB_URL" tmp/#{buildpack}-buildpack
      cd tmp/#{buildpack}-buildpack
      export BUNDLE_GEMFILE=cf.Gemfile
      bundle install
      bundle exec buildpack-packager --cached
      cf delete-buildpack #{buildpack}-brat-buildpack -f
      cf create-buildpack #{buildpack}-brat-buildpack $(ls *_buildpack-cached*.zip | head -n 1) 100 --enable

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
