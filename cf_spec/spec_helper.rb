require 'bundler/setup'
require 'machete'
require 'machete/matchers'

Dir[File.join(File.dirname(__FILE__), 'support', '**', '*.rb')].each { |f| require f }

`mkdir -p log`
Machete.logger = Machete::Logger.new("log/integration.log")
