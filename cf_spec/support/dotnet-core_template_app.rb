class DotnetCoreTemplateApp
  attr_reader :sdk_version, :framework_version, :full_path

  def initialize(sdk_version, framework_version)
    @sdk_version = sdk_version
    @framework_version = framework_version
  end

  def path
    Shellwords.shellescape("dotnet-core/tmp/#{sdk_version}/simple_brats")
  end

  def name
    @name ||= "simple-dotnet-#{Time.now.to_i}"
  end

  def generate!
    origin_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'dotnet-core', 'simple_brats')
    copied_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'dotnet-core', 'tmp', sdk_version.to_s, 'simple_brats')
    @full_path = File.expand_path(copied_template_path)
    FileUtils.rm_rf(copied_template_path)
    FileUtils.mkdir_p(File.dirname(copied_template_path))
    FileUtils.cp_r(origin_template_path, copied_template_path)

    major, minor, _ = @framework_version.split('.')
    if major == '1' && minor == '1'
      net_core_app = 'netcoreapp1.1'
    else
      net_core_app = 'netcoreapp1.0'
    end

    project = {
      'buildOptions' => {
        'emitEntryPoint' => true,
        "debugType" => "portable"
      },
      "dependencies" => {
        "Microsoft.AspNetCore.Server.IISIntegration" => "1.*",
        "Microsoft.AspNetCore.Server.Kestrel" => "1.*",
        "Microsoft.NETCore.App" => {
          "type" => "platform",
          "version" => framework_version
        },
        "Microsoft.Extensions.Configuration.CommandLine" => "1.*"
      },
      "frameworks" => {
        net_core_app => { }
      },
      "tools" => {
        "Microsoft.AspNetCore.Server.IISIntegration.Tools" => {
          "version" => sdk_version,
          "imports" => "portable-net45+wp80+win8+wpa81+dnxcore50"
        }
      }
    }


    File.write(
      File.join(copied_template_path, 'project.json'),
      JSON.generate(project)
    )

    global = {
      "projects" => [ "src", "test" ],
      "sdk" => {
        "version" => sdk_version
      }
    }

    File.write(
      File.join(copied_template_path, 'global.json'),
      JSON.generate(global)
    )

  end
end
