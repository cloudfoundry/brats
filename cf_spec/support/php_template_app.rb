class PHPTemplateApp
  attr_reader :runtime_version, :web_server, :web_server_version, :options

  def initialize(runtime_version:, web_server:, web_server_version:)
    @runtime_version = runtime_version
    @web_server  = web_server
    @web_server_version = web_server_version
  end

  def path
    Shellwords.shellescape("php/tmp/#{runtime_version}/simple_brats")
  end

  def name
    @name ||= "simple-php-#{Time.now.to_i}"
  end

  def generate!
    origin_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'php', 'simple_brats')
    copied_template_path = File.join(File.dirname(__FILE__), '..', 'fixtures', 'php', 'tmp', runtime_version.to_s, 'simple_brats')
    FileUtils.rm_rf(copied_template_path)
    FileUtils.mkdir_p(File.dirname(copied_template_path))
    FileUtils.cp_r(origin_template_path, copied_template_path)

    php_extensions = {}

    external_extensions = %w(
      amqp
      igbinary
      imagick
      intl
      lua
      mailparse
      memcache
      memcached
      mongo
      msgpack
      phalcon
      phpiredis
      protobuf
      protocolbuffers
      redis
      suhosin
      sundown
      twig
      xcache
      xdebug
      yaf)
    included_extensions = %w(
      bz2
      curl
      dba
      exif
      fileinfo
      ftp
      gd
      gettext
      gmp
      imap
      ldap
      mbstring
      mcrypt
      mysqli
      openssl
      pdo
      pdo_mysql
      pdo_pgsql
      pdo_sqlite
      pgsql
      pspell
      soap
      sockets
      xsl
      zip
      zlib)
    php5_included_extensions = %w(
      mysql
      phalcon
    )
    php_extensions['5.6'] = included_extensions + php5_included_extensions + external_extensions
    php_extensions['5.5'] = included_extensions + php5_included_extensions + external_extensions + ['xhprof']
    php_extensions['5.4'] = php_extensions['5.6'] # TODO: deprecated, to be removed in next release
    php_extensions['7.0'] = included_extensions + %w(
      mailparse
      mongodb
      msgpack
      yaf
      lua
    )

    to_major_minor_version = lambda do |full_version|
      full_version.split('.')[0..1].inject { |x, y| "#{x}.#{y}" }
    end

    @options = {
      'PHP_VM'                       => 'php',
      'PHP_VERSION'                  => runtime_version,
      'WEB_SERVER'                   => web_server,
      'PHP_EXTENSIONS'               => php_extensions[to_major_minor_version.call(runtime_version)],
      'ZEND_EXTENSIONS'              => ['ioncube'],
      "#{web_server.upcase}_VERSION" => web_server_version
    }

    File.write(
      File.join(copied_template_path, '.bp-config', 'options.json'),
      JSON.generate(options)
    )
  end
end
