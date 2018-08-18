require 'active_record'
require 'activerecord-jdbcmysql-adapter'
require 'compilation_slice'
class Job < ActiveRecord::Base
  establish_connection(
    adapter:  "mysql",
    host:     "10.131.252.160",
    username: "root",
    password: "root",
    database: "zc",
    encoding: "utf8mb4",
    collation: "utf8mb4_bin"
  )
  has_one :compilation_slice
end