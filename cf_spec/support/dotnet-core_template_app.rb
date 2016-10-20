class DotnetCoreTemplateApp
  attr_reader :dotnet_version, :runtime_version, :full_path

  def initialize(dotnet_version, runtime_version)
    @dotnet_version = dotnet_version
    @runtime_version = runtime_version
  end

  def path
    Shellwords.shellescape("dotnet-core/tmp/#{dotnet_version}/simple_brats")
  end

  def name
    @name ||= "simple-dotnet-#{Time.now.to_i}"
  end

  def generate!
    origin_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'dotnet-core', 'simple_brats')
    copied_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'dotnet-core', 'tmp', dotnet_version.to_s, 'simple_brats')
    @full_path = File.expand_path(copied_template_path)
    FileUtils.rm_rf(copied_template_path)
    FileUtils.mkdir_p(File.dirname(copied_template_path))
    FileUtils.cp_r(origin_template_path, copied_template_path)

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
          "version" => runtime_version
        },
        "Microsoft.Extensions.Configuration.CommandLine" => "1.*"
      },
      "frameworks" => {
        "netcoreapp1.0"=> { }
      },
      "tools" => {
        "Microsoft.AspNetCore.Server.IISIntegration.Tools" => {
          "version" => dotnet_version,
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
        "version" => dotnet_version
      }
    }

    File.write(
      File.join(copied_template_path, 'global.json'),
      JSON.generate(global)
    )

  end
end
