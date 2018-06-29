require 'active_record'
require 'activerecord-jdbcmysql-adapter'
class Location < ActiveRecord::Base
  establish_connection(
    adapter:  "mysql",
    host:     "10.131.252.160",
    username: "root",
    password: "root",
    database: "zc"
  )
end