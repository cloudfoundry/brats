require 'sinatra'
require 'nokogiri'

get '/' do
  'Hello, World'
end

get '/nokogiri' do
  doc = Nokogiri::XML(open('test.xml'))
  doc.xpath("//xml")
end
