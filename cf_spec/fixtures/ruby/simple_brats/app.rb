require 'bcrypt'
require 'bson'
require 'eventmachine'
require 'mysql'
require 'nokogiri'
require 'pg'
require 'sinatra'

get '/' do
  'Hello, World'
end

get '/nokogiri' do
  doc = Nokogiri::XML(open('test.xml'))
  doc.xpath("//xml")
end

get '/em' do
  body = nil
  EM.run do
    EM.next_tick do
      body = 'Hello, EventMachine'
      EM.stop
    end
  end
  body
end

get '/bcrypt' do
  BCrypt::Password.create("Hello, bcrypt")
end

get '/bson' do
  1024.to_bson.unpack('H*').first
end

get '/pg' do
  begin
    PG.connect(dbname: 'Test')
  rescue PG::ConnectionBad => e
    e.message
  end
end

get '/mysql' do
  begin
    Mysql.new('testing')
  rescue Mysql::Error => e
    e.message
  end
end
