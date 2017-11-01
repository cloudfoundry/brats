require 'spec_helper'

def generate_nodejs_app(nodejs_version)
  template = NodeJSTemplateApp.new(nodejs_version)
  template.generate!
  template
end

RSpec.shared_examples :a_deploy_of_nodejs_app_with_version_range do |nodejs_version, stack|
  context "with node #{nodejs_version}" do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      app_template = generate_nodejs_app(nodejs_version)
      @app = deploy_app(template: app_template, stack: stack, buildpack: 'nodejs-brat-buildpack')
    end

    after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

    it 'should be running' do
      expect(@app).to be_running
      2.times do
        browser.visit_path('/')
        expect(browser).to have_body('Hello World!')
      end
    end

    it 'should have the correct version' do
      expect(@app).to_not have_logged /Downloading and installing undefined.../
      expect(@app).to have_logged /engines.node \(package.json\).*#{nodejs_version}/
      expect(@app).to have_logged /installing node\s*\d+\.\d+\.\d+/i
    end
  end
end

RSpec.shared_examples :a_deploy_of_nodejs_app_to_cf do |nodejs_version, stack|
  context "with node #{nodejs_version}", version: nodejs_version do
    let(:browser) { Machete::Browser.new(@app) }

    before(:all) do
      app_template = generate_nodejs_app(nodejs_version)
      @app = deploy_app(template: app_template, stack: stack, buildpack: 'nodejs-brat-buildpack')
    end

    after(:all) { Machete::CF::DeleteApp.new.execute(@app) }

    it 'should be running' do
      expect(@app).to be_running
      2.times do
        browser.visit_path('/')
        expect(browser).to have_body('Hello World!')
      end
    end

    it 'supports bcrypt' do
      expect(@app).to be_running
      2.times do
        browser.visit_path('/bcrypt')
        expect(browser).to have_body('Hello Bcrypt!')
      end
    end

    # bson-ext does not support the v8 engine and hence node 6, 7, 8 and 9
    # context: https://github.com/christkv/bson-ext/issues/28#issuecomment-212258411
    unless /[6789]\.\d+\.\d+/ =~ nodejs_version
      it 'supports bson-ext' do
        expect(@app).to be_running
        2.times do
          browser.visit_path('/bson-ext')
          expect(browser).to have_body('Hello Bson-ext!')
        end
      end
    end

    it 'should have the correct version' do
      expect(@app).to have_logged(/installing node\s*#{nodejs_version}/i)
    end
  end
end

describe 'For the nodejs buildpack', language: 'nodejs' do
  after(:all) do
    cleanup_buildpack(buildpack: 'nodejs')
  end

  describe 'deploying an app with an updated version of the same buildpack' do
    let(:stack)          { 'cflinuxfs2' }
    let(:nodejs_version) { dependency_versions_in_manifest('nodejs', 'node', stack).last }
    let(:app) do
      app_template = generate_nodejs_app(nodejs_version)
      deploy_app(template: app_template, stack: stack, buildpack: 'nodejs-brat-buildpack')
    end

    before(:all) do
      cleanup_buildpack(buildpack: 'nodejs')
      install_buildpack(buildpack: 'nodejs')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'prints useful warning message to stdout' do
      expect(app).to_not have_logged(/WARNING.*buildpack version changed from/)
      bump_buildpack_version(buildpack: 'nodejs')
      Machete.push(app)
      expect(app).to have_logged(/WARNING.*buildpack version changed from/)
    end
  end

  describe 'staging with a version of node that is not the latest patch release in the manifest' do
    let(:stack)      { 'cflinuxfs2' }
    let(:node_version) do
      dependency_versions_in_manifest('nodejs', 'node', stack).sort do |ver1, ver2|
        Gem::Version.new(ver1) <=> Gem::Version.new(ver2)
      end.first
    end

    let(:app) do
      app_template = generate_nodejs_app(node_version)
      deploy_app(template: app_template, stack: stack, buildpack: 'nodejs-brat-buildpack')
    end

    before do
      cleanup_buildpack(buildpack: 'nodejs')
      install_buildpack(buildpack: 'nodejs')
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    it 'logs a warning that tells the user to upgrade the dependency' do
      expect(app).to have_logged(/WARNING.*A newer version of node is available in this buildpack/)
    end
  end

  describe 'Deploying CF apps' do
    before(:all) do
      cleanup_buildpack(buildpack: 'nodejs')
      install_buildpack(buildpack: 'nodejs')
    end

    if is_current_user_language_tag?('nodejs')
      ['cflinuxfs2'].each do |stack|
        context "on the #{stack} stack", stack: stack do

          nodejs_versions = dependency_versions_in_manifest('nodejs', 'node', stack)

          nodejs_versions.each do |nodejs_version|
            it_behaves_like :a_deploy_of_nodejs_app_to_cf, nodejs_version, stack
          end

          nodejs_versions.map { |nodejs_version|
            '~>' + /(\d+)\.(\d+)/.match(nodejs_version)[0] + '.0'
          }.uniq.each do |squiggle_version|
            it_behaves_like :a_deploy_of_nodejs_app_with_version_range, squiggle_version, stack
          end
        end
      end
    end
  end

  describe 'staging with custom buildpack that sets EOL on dependency' do
    let(:stack)          { 'cflinuxfs2' }
    let(:nodejs_version) { dependency_versions_in_manifest('nodejs', 'node', stack).last }
    let(:app) do
      app_template = generate_nodejs_app(nodejs_version)
      deploy_app(template: app_template, stack: stack, buildpack: 'nodejs-brat-buildpack')
    end
    let(:version_line) { nodejs_version.gsub(/\.\d+\.\d+$/,'') }
    let(:eol_date) { (Date.today + 10) }
    let(:warning_message) { /WARNING.*node #{version_line} will no longer be available in new buildpacks released after/ }

    before do
      cleanup_buildpack(buildpack: 'nodejs')
      install_buildpack(buildpack: 'nodejs', buildpack_caching: caching) do
        hash = YAML.load_file('manifest.yml')
        hash['dependency_deprecation_dates'] = [{
          'match' => version_line + '\.\d',
          'version_line' => version_line,
          'name' => 'node',
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

    context "eol is more than 30 days in the future" do
      let(:caching)        { :uncached }
      let(:eol_date) { (Date.today + 40) }

      it 'does not warn about end of life' do
        expect(app).to_not have_logged(warning_message)
      end
    end
  end

  describe 'staging with custom buildpack that uses credentials in manifest dependency uris' do
    let(:stack)          { 'cflinuxfs2' }
    let(:nodejs_version) { dependency_versions_in_manifest('nodejs', 'node', stack).last }
    let(:app) do
      app_template = generate_nodejs_app(nodejs_version)
      deploy_app(template: app_template, stack: stack, buildpack: 'nodejs-brat-buildpack')
    end

    before do
      cleanup_buildpack(buildpack: 'nodejs')
      install_buildpack_with_uri_credentials(buildpack: 'nodejs', buildpack_caching: caching)
    end

    after { Machete::CF::DeleteApp.new.execute(app) }

    context "using an uncached buildpack" do
      let(:caching)        { :uncached }
      let(:credential_uri) { Regexp.new(Regexp.quote('https://') + 'login:password[@]') }
      let(:node_uri)       { Regexp.new(/node-[\d\.]+-linux-x64-[\da-f]+.tgz/) }

      it 'does not include credentials in logged dependency uris' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to_not have_logged("password")
        expect(app).to have_logged(node_uri)
      end
    end

    context "using a cached buildpack" do
      let(:caching)        { :cached }
      let(:credential_uri) { Regexp.new('https___login_password') }
      let(:node_uri)       { Regexp.new(/node-[\d\.]+-linux-x64-[\da-f]+.tgz/) }

      it 'does not include credentials in logged dependency file paths' do
        expect(app).to_not have_logged(credential_uri)
        expect(app).to_not have_logged("password")
        expect(app).to have_logged(node_uri)
      end
    end
  end

  describe 'deploying an app that has an executable .profile script' do
    let(:stack)          { 'cflinuxfs2' }
    let(:nodejs_version) { dependency_versions_in_manifest('nodejs', 'node', stack).last }
    let(:app) do
      app_template = generate_nodejs_app(nodejs_version)
      add_dot_profile_script_to_app(app_template.full_path)
      deploy_app(template: app_template, stack: stack, buildpack: 'nodejs-brat-buildpack')
    end
    let(:browser) { Machete::Browser.new(app) }

    before(:all) do
      skip_if_no_dot_profile_support_on_targeted_cf
      cleanup_buildpack(buildpack: 'nodejs')
      install_buildpack(buildpack: 'nodejs')
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
    let(:stack)          { 'cflinuxfs2' }
    let(:nodejs_version) { dependency_versions_in_manifest('nodejs', 'node', stack).last }
    let(:app) do
      app_template = generate_nodejs_app(nodejs_version)
      deploy_app(template: app_template, stack: stack, buildpack: 'nodejs-brat-buildpack')
    end

    before(:all) do
      cleanup_buildpack(buildpack: 'nodejs')
      install_buildpack(buildpack: 'nodejs')
    end

    it 'will not write credentials to the app droplet' do
      expect(app).to be_running
      expect(app.name).to keep_credentials_out_of_droplet
    end
  end
end
