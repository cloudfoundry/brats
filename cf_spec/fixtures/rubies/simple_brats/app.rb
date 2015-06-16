require 'sinatra'
require 'nokogiri'
require 'eventmachine'
require 'bcrypt'
require 'bson'

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

if RUBY_PLATFORM == 'java'
  require 'jdbc/mysql'
  require 'jdbc/postgres'

  Jdbc::MySQL.load_driver
  Jdbc::Postgres.load_driver

  get '/pg' do
    begin
      userurl = 'jdbc:postgresql://HOST/DATABASE'
      java.sql.DriverManager.get_connection(userurl, 'USERNAME', 'PASSWORD')
    rescue => e
      e.message
    end
  end

  get '/mysql' do
    begin
      userurl = 'jdbc:mysql://HOST/DATABASE'
      java.sql.DriverManager.get_connection(userurl, 'USERNAME', 'PASSWORD')
    rescue => e
      e.message
    end
  end
else
  require 'mysql'
  require 'pg'

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

  require 'rmagick'

  get '/rmagick' do
    # Image from https://upload.wikimedia.org/wikipedia/commons/5/54/%28View_of_Troldhaugen_and_Nord%C3%A5svannet%29_%284007745063%29.jpg
    image = Magick::Image.read(open('image.jpg')).first
    "width #{image.columns} height #{image.rows}"
  end
end