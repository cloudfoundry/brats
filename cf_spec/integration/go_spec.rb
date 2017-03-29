require 'spec_helper'

def generate_go_app(go_version)
  template = GoTemplateApp.new(go_version)
  template.generate!
  template
end

RSpec.shared_examples :a_deploy_of_go_app_to_cf do |go_version, stack|
  context "with Go version #{go_version}" do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      app_template = generate_go_app(go_version)
      @app = deploy_app(template: app_template, stack: stack, buildpack: 'go-brat-buildpack')
    end

    after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

    it 'runs a simple webserver with correct go version' do
      expect(@app).to be_running(120)
      expect(@app).to have_logged "Installing go\s*#{go_version}"
    end

    it 'has content at the root' do
      2.times do
        browser.visit_path('/')
        expect(browser).to have_body('Hello, World')
      end
    end
  end
end

describe 'For all supported Go versions', language: 'go' do
  let(:stack) { 'cflinuxfs2' }

  before(:all) do
    cleanup_buildpack(buildpack: 'go')
    install_buildpack(buildpack: 'go')
  end

  after(:all) do
    cleanup_buildpack(buildpack: 'go')
  end

  if is_current_user_language_tag?('go')
    ['cflinuxfs2'].each do |stack|
      context "on the #{stack} stack", stack: stack do
        go_versions = dependency_versions_in_manifest('go','go',stack)
        go_versions.each do |go_version|
          it_behaves_like :a_deploy_of_go_app_to_cf, go_version, stack
        end
      end
    end
  end

  describe 'deploying an app with an updated version of the same buildpack' do
    let(:stack)      { 'cflinuxfs2' }
    let(:go_version) { dependency_versions_in_manifest('go', 'go', stack).last }
    let(:app) do
      app_template = generate_go_app(go_version)
      deploy_app(template: app_template, stack: stack, buildpack: 'go-brat-buildpack')
    end

    before(:all) do
      cleanup_buildpack(buildpack: 'go')
      install_buildpack(buildpack: 'go')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'prints useful warning message to stdout' do
      expect(app).to_not have_logged(/WARNING(:|\*\*) buildpack version changed from/)
      bump_buildpack_version(buildpack: 'go')
      Machete.push(app)
      expect(app).to have_logged(/WARNING(:|\*\*) buildpack version changed from/)
    end
  end

  describe 'staging with custom buildpack that uses credentials in manifest dependency uris' do
    let(:stack)      { 'cflinuxfs2' }
    let(:go_version) { dependency_versions_in_manifest('go', 'go', stack).last }
    let(:app) do
      app_template = generate_go_app(go_version)
      deploy_app(template: app_template, stack: stack, buildpack: 'go-brat-buildpack')
    end

    before do
      cleanup_buildpack(buildpack: 'go')
      install_buildpack_with_uri_credentials(buildpack: 'go', buildpack_caching: caching)
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    context "using an uncached buildpack" do
      let(:caching)        { :uncached }
      let(:credential_uri) { Regexp.new(Regexp.quote('https://') + 'login:password[@]') }
      let(:go_uri)       { Regexp.new(Regexp.quote('https://-redacted-:-redacted-@buildpacks.cloudfoundry.org/dependencies/go/go') + '[\d\.]+' + Regexp.quote('.linux-amd64-') + '[\da-f]+\.tar\.gz') }

      it 'does not include credentials in logged dependency uris' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to have_logged(go_uri)
      end
    end

    context "using a cached buildpack" do
      let(:caching)        { :cached }
      let(:credential_uri) { Regexp.new('https___login_password') }
      let(:go_uri)       { Regexp.new(Regexp.quote('https___-redacted-_-redacted-@buildpacks.cloudfoundry.org_dependencies_go_go') + '[\d\.]+' + Regexp.quote('.linux-amd64-') + '[\da-f]+\.tar\.gz') }

      it 'does not include credentials in logged dependency file paths' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to have_logged(go_uri)
      end
    end
  end

  describe 'staging with a version of go that is not the latest patch release in the manifest' do
    let(:stack)      { 'cflinuxfs2' }
    let(:go_version) do
      dependency_versions_in_manifest('go', 'go', stack).sort do |ver1, ver2|
        Gem::Version.new(ver1) <=> Gem::Version.new(ver2)
      end.first
    end

    let(:app) do
      app_template = generate_go_app(go_version)
      deploy_app(template: app_template, stack: stack, buildpack: 'go-brat-buildpack')
    end

    before do
      cleanup_buildpack(buildpack: 'go')
      install_buildpack(buildpack: 'go')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'logs a warning that tells the user to upgrade the dependency' do
      expect(app).to have_logged(/\*\*WARNING\*\* A newer version of go is available in this buildpack/)
    end
  end

  describe 'deploying an app that has an executable .profile script' do
    let(:go_version) { dependency_versions_in_manifest('go', 'go', stack).last }
    let(:app) do
      app_template = generate_go_app(go_version)
      add_dot_profile_script_to_app(app_template.full_path)
      deploy_app(template: app_template, stack: stack, buildpack: 'go-brat-buildpack')
    end
    let(:browser) { Machete::Browser.new(app) }

    before(:all) do
      skip_if_no_dot_profile_support_on_targeted_cf
      cleanup_buildpack(buildpack: 'go')
      install_buildpack(buildpack: 'go')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'executes the .profile script' do
      expect(app).to have_logged("PROFILE_SCRIPT_IS_PRESENT_AND_RAN")
    end

    it 'does not let me view the .profile script' do
      browser.visit_path('/.profile', allow_404: true)
      expect(browser).to_not have_body 'PROFILE_SCRIPT_IS_PRESENT_AND_RAN'
    end
  end

  describe 'deploying an app that has sensitive environment variables' do
    let(:stack)      { 'cflinuxfs2' }
    let(:go_version) { dependency_versions_in_manifest('go', 'go', stack).last }
    let(:app) do
      app_template = generate_go_app(go_version)
      deploy_app(template: app_template, stack: stack, buildpack: 'go-brat-buildpack')
    end

    before(:all) do
      cleanup_buildpack(buildpack: 'go')
      install_buildpack(buildpack: 'go')
    end

    it 'will not write credentials to the app droplet' do
      expect(app).to be_running
      expect(app.name).to keep_credentials_out_of_droplet
    end
  end
end

describe 'staging with go buildpack that sets EOL on dependency' do
  let(:stack)      { 'cflinuxfs2' }
  let(:go_version) { dependency_versions_in_manifest('go', 'go', stack).last }
  let(:app) do
    app_template = generate_go_app(go_version)
    deploy_app(template: app_template, stack: stack, buildpack: 'go-brat-buildpack')
  end
  let(:version_line) { go_version.gsub(/\.\d+$/,'') }
  let(:eol_date) { (Date.today + 10) }
  let(:warning_message) { /WARNING(:|\*\*) go #{version_line} will no longer be available in new buildpacks released after/ }

  before do
    cleanup_buildpack(buildpack: 'go')
    install_buildpack(buildpack: 'go', buildpack_caching: caching) do
      hash = YAML.load_file('manifest.yml')
      hash['dependency_deprecation_dates'] = [{
        'match' => version_line + '\.\d+',
        'version_line' => version_line,
        'name' => 'go',
        'date' => eol_date
      }]
      File.write('manifest.yml', hash.to_yaml)
    end
  end

  after { Machete::CF::DeleteApp.new.execute(app) }

  context "using an uncached buildpack" do
    let(:caching)        { :uncached }

    it 'warns about end of life' do
      expect(app).to have_logged(warning_message)
    end
  end

  context "using an uncached buildpack" do
    let(:caching)        { :cached }

    it 'warns about end of life' do
      expect(app).to have_logged(warning_message)
    end
  end
end
