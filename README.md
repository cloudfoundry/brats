Buildpack Runtime Acceptance Tests
---

## Deprecation

This repo is in the process of being replaced by brats tests inside each
buildpack repo.  To run BRATs tests we recommend using those new tests. As an
example, to run BRATs for the ruby buildpack:

```
mkdir -p ~/workspace
cd ~/workspace

git clone https://github.com/cloudfoundry/ruby-buildpack.git
cd ~/workspace/ruby-buildpack

cf api api.cf-deployment.com

./scripts/brats.sh
```

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

rspec cf_spec/integration/ruby_spec.rb --tag language:ruby --tag buildpack_branch:develop
```

Note that the appropriate language tag is required to run the full BRATS suite for the specified buildpack.
The interpreter matrix tests will not execute unless the tag for the appropriate interpreter is passed into the rspec arguments.

It is required to specify a git branch of the buildpack to test against. This is done by passing `--tag buildpack_branch:<git branch>` to rspec.
