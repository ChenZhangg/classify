require 'active_record'
require 'activerecord-jdbcmysql-adapter'
class WrongSlice < ActiveRecord::Base
  establish_connection(
    adapter:  "mysql",
    host:     "10.131.252.160",
    username: "root",
    password: "root",
    database: "zc",
    encoding: "utf8mb4",
    collation: "utf8mb4_bin"
  )
  serialize :maven_slice, Array
  serialize :gradle_slice, Array
end