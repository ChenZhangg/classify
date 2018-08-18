require 'active_record'
require 'activerecord-jdbcmysql-adapter'
require 'job'
class CompilationSlice < ActiveRecord::Base
  establish_connection(
      adapter:  "mysql",
      host:     "10.131.252.160",
      username: "root",
      password: "root",
      database: "zc",
      encoding: "utf8mb4",
      collation: "utf8mb4_bin"
  )
  belongs_to :job
  #serialize :maven_slice, Array
  #serialize :gradle_slice, Array
  serialize :maven_warning_slice, Array
end