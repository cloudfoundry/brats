class PHPTemplateApp
  attr_reader :runtime_version, :web_server, :web_server_version, :options, :full_path

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
    @full_path = File.expand_path(copied_template_path)
    FileUtils.rm_rf(copied_template_path)
    FileUtils.mkdir_p(File.dirname(copied_template_path))
    FileUtils.cp_r(origin_template_path, copied_template_path)

    common_extensions = %w(
         amqp
         apcu
         bz2
         cassandra
         curl
         dba
         exif
         fileinfo
         ftp
         gd
         gettext
         gmp
         imagick
         imap
         ldap
         lua
         mailparse
         mbstring
         mcrypt
         mongodb
         msgpack
         mysqli
         openssl
         pcntl
         pdo
         pdo_mysql
         pdo_pgsql
         pdo_sqlite
         pgsql
         phpiredis
         pspell
         rdkafka
         redis
         snmp
         soap
         sockets
         solr
         xsl
         yaf
         zip
         zlib)

    # remove snmp b/c it is generating too many errors
    # revert this once #137833437 is complete
    common_extensions = common_extensions - %w(snmp)

    php5_extensions = %w(
         gearman
         igbinary
         memcache
         memcached
         mongo
         mssql
         mysql
         pdo_dblib
         phalcon
         protobuf
         protocolbuffers
         readline
         suhosin
         sundown
         twig
         xcache
         xhprof)

    php7_0_extensions = %w(
         phalcon)

    major_minor_version = runtime_version.split('.')[0..1].inject { |x, y| "#{x}.#{y}" }

    @options = {
      'PHP_VM'                       => 'php',
      'PHP_VERSION'                  => runtime_version,
      'WEB_SERVER'                   => web_server,
      "#{web_server.upcase}_VERSION" => web_server_version
    }

    case major_minor_version
    when '7.1' then
      @options['PHP_EXTENSIONS'] = common_extensions
      @options['ZEND_EXTENSIONS'] = %w(ioncube opcache)
    when '7.0' then
      @options['PHP_EXTENSIONS'] = common_extensions + php7_0_extensions
      @options['ZEND_EXTENSIONS'] = %w(ioncube opcache xdebug)
    when '5.5', '5.6' then
      @options['PHP_EXTENSIONS'] = common_extensions + php5_extensions
      @options['ZEND_EXTENSIONS'] = %w(ioncube opcache xdebug)
    end

    File.write(
      File.join(copied_template_path, '.bp-config', 'options.json'),
      JSON.generate(options)
    )
  end
end
