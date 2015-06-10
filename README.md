# Usage

Example of testing the Ruby buildpack:

```sh
mkdir -p ~/workspace
cd ~/workspace

git clone https://github.com/pivotal-cf/brats
cd ~/workspace/brats
bundle install

cf api api.cf-deployment.com

rspec cf_spec/integration/ruby_spec.rb
```
