Buildpack Runtime Acceptance Tests
---

### Functionality

Test that the compiled binaries of the buildpacks are working as expected.

### Usage

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
