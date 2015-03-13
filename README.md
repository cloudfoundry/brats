# Usage

Example of testing the Ruby buildpack:

```sh
mkdir -p ~/workspace
cd ~/workspace

git clone https://github.com/pivotal-cf/brats
cd ~/workspace/brats
BUNDLE_GEMFILE=cf.Gemfile bundle install

git clone https://github.com/cloudfoundry/ruby-buildpack
cd ~/workspace/ruby-buildpack
git submodule update --init --recursive
BUNDLE_GEMFILE=cf.Gemfile bundle install

cf api api.cf-deployment.com

cd ~/workspace/brats
./bin/tests --language=ruby
```
