require 'bundler/setup'
require 'machete'
require 'machete/matchers'
require 'open-uri'
require 'json'

`mkdir -p log`
Machete.logger = Machete::Logger.new("log/integration.log")
