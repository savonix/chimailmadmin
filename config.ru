
if ENV['RACK_ENV'] == "demo"
  mountpath = '/demo/chimailmadmin'
  dirpfx = '/var/www/dev/chimailr/current'
  ENV['DATABASE_URL'] = 'sqlite3:///var/www/dev/chimailr/rbeans.sqlite3'
elsif ENV['RACK_ENV'] == "development"
  mountpath = '/'
  dirpfx = '/var/www/dev/chimailmadmin'
  ENV['DATABASE_URL'] = 'sqlite3:///var/www/dev/chimailmadmin/rbeans.sqlite3'
else
  mountpath = '/'
end

require File.dirname(__FILE__) + '/chimailmadmin'


map mountpath do
  conf = Hash['uripfx', mountpath, "b", 201]
  myapp = Chimailmadmin.new(conf)
  myapp.set :environment, 'development'
  run myapp
end