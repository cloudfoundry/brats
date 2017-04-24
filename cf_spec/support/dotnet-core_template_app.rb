class DotnetCoreTemplateApp
  attr_reader :sdk_version, :framework_version, :full_path

  def initialize(sdk_version, framework_version)
    @sdk_version = sdk_version
    @framework_version = framework_version
  end

  def path
    Shellwords.shellescape("dotnet-core/tmp/#{sdk_version}/#{framework_version}/simple_brats")
  end

  def name
    @name ||= "simple-dotnet-#{Time.now.to_i}"
  end

  def generate!
    origin_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'dotnet-core', 'simple_brats')
    @copied_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'dotnet-core', 'tmp', sdk_version.to_s , framework_version.to_s ,'simple_brats')
    @full_path = File.expand_path(@copied_template_path)
    FileUtils.rm_rf(@copied_template_path)
    FileUtils.mkdir_p(File.dirname(@copied_template_path))
    FileUtils.cp_r(origin_template_path, @copied_template_path)

    major, minor, _ = @framework_version.split('.')
    if major == '1' && minor == '1'
      net_core_app = 'netcoreapp1.1'
    else
      net_core_app = 'netcoreapp1.0'
    end

    if sdk_msbuild?(sdk_version: @sdk_version)
      write_csproj_file(framework_version, net_core_app)
    else
      write_project_json_file(framework_version, net_core_app)
    end

    global = {
      "projects" => [ "src", "test" ],
      "sdk" => {
        "version" => sdk_version
      }
    }

    File.write(
      File.join(@copied_template_path, 'global.json'),
      JSON.generate(global)
    )

  end

  def write_project_json_file(framework_version, net_core_app)
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
      }
    }

    File.write(
      File.join(@copied_template_path, 'project.json'),
      JSON.generate(project)
    )
  end

  def write_csproj_file(framework_version, net_core_app)

    csproj_xml = <<-XML
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>#{net_core_app}</TargetFramework>
    <DebugType>portable</DebugType>
    <AssemblyName>simple_brats</AssemblyName>
    <OutputType>Exe</OutputType>
    <RuntimeFrameworkVersion>#{framework_version}</RuntimeFrameworkVersion>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.Server.IISIntegration">
      <Version>1.*</Version>
    </PackageReference>
    <PackageReference Include="Microsoft.AspNetCore.Server.Kestrel">
      <Version>1.*</Version>
    </PackageReference>
    <PackageReference Include="Microsoft.Extensions.Configuration.CommandLine">
      <Version>1.*</Version>
    </PackageReference>
  </ItemGroup>

  <PropertyGroup Condition=" '$(Configuration)' == 'Release' ">
    <DefineConstants>$(DefineConstants);RELEASE</DefineConstants>
  </PropertyGroup>
</Project>
XML

    File.write(
      File.join(@copied_template_path, 'simple_brats.csproj'),
      csproj_xml
    )

  end
end
