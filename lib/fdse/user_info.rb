require 'json'
require 'active_record'
require 'activerecord-jdbcmysql-adapter'
require 'activerecord-import'
require 'thread'
require 'user'
require 'location'
require 'geocoder'
require 'timezone'
require 'open-uri'
module Fdse
  module UserInfo
    def self.parse_json_file(file_path, travis_id)
      hash = Hash.new
      j = JSON.parse IO.read(file_path)
      hash[:travis_id] = travis_id.to_i
      hash[:github_id] = j['id'].to_i
      hash[:login] = j['login']
      hash[:name] = j['name']
      hash[:location] = j['location']
      @out_queue.enq hash
    end
  
    def self.thread_init
      @in_queue = SizedQueue.new(31)
      @out_queue = SizedQueue.new(200)
      consumer = Thread.new do
        id = 0
        loop do
          bulk = []
          hash = nil
          200.times do
            hash = @out_queue.deq
            break if hash == :END_OF_WORK
            id += 1
            hash[:id] = id
            bulk << User.new(hash)
          end
          User.import bulk
          break if hash == :END_OF_WORK
        end
      end
  
      threads = []
      31.times do
        thread = Thread.new do
          loop do
            hash = @in_queue.deq
            break if hash == :END_OF_WORK
            parse_json_file hash[:file_path], hash[:travis_id]
          end
        end
        threads << thread
      end
      [consumer, threads]
    end
  
    def self.scan_json_files
      Thread.abort_on_exception = true
      json_files_path = File.expand_path(File.join('..', '..', '..', 'bodyLog2', 'github'), File.dirname(__FILE__))

      consumer, threads = thread_init
      regexp = /(.+)@(.+)/
      Dir.foreach(json_files_path) do |file_name|
        m = regexp.match file_name
        next if m.nil?
        file_path = File.join(json_files_path, file_name)
        puts "Scan #{file_path}"
        hash = Hash.new
        hash[:file_path] = file_path
        hash[:travis_id] = m[1]
        @in_queue.enq hash
      end
  
      31.times do
        @in_queue.enq :END_OF_WORK
      end
      threads.each { |t| t.join }
      @out_queue.enq(:END_OF_WORK)
      consumer.join
      puts "Scan Over"
    end
  
    def self.get_timezone
      microsoft_key = "Ar4ssnlEILYgCEeG-FsQbWoQ5gJ76MVT2zjT5bc9-MN8cwcjgZHWd8M9LokUYUxy"
      baidu_key = "FbT8WvUs610W7Vslb61CPfyDmsAKuYPU"
      Geocoder.configure(lookup: :bing, api_key: microsoft_key, timeout: 100)
      Location.where("id > 1773").find_each do |item|
        puts "#{item.id}  #{item.location}"
        results = Geocoder.search item.location
        if results.first
          ll = results.first.coordinates 
          results = Geocoder.search ll
          item.latitude = ll[0]
          item.longitude = ll[1]
          item.address = results.first.address if results.first
          url = "http://api.map.baidu.com/timezone/v1?coord_type=wgs84ll&location=#{ll[0]},#{ll[1]}&timestamp=1473130354&ak=#{baidu_key}"
          open(url) do |f|
            j = JSON.parse(f.read)
            item.timezone = j['timezone_id']
          end
        end
        item.save
      end
    end
  end
end

=begin
require 'geokit'
require 'timezone'
require 'geocoder'
Geocoder.configure(  
  # geocoding options
  :timeout      => 10,           # geocoding service timeout (secs)
  :use_https    => true,        # use HTTPS for lookup requests? (if supported)
  :api_key      => 'AIzaSyAlHpw2sek1wYr-uQ9Rbu5YH0ynBYn8EaQ'         # API key for geocoding service
 )
results = Geocoder.search("Paris")
p results
#Nantes
#Geokit::Geocoders::provider_order = [:google3, :us]
#Geokit::Geocoders::Google3Geocoder = Geokit::Geocoders::GoogleGeocoder3
#a = Geokit::Geocoders::GoogleGeocoder.geocode '789 Geary St, San Francisco, CA'
#p a

#timezone = Timezone::Zone.new(:latlon => res.ll) Tokyo, Japan
#timezone = Timezone['America/Los_Angeles']
#timezone = Timezone['Japan/Tokyo']

#p timezone
      address = "中国,广东,广州"
      results = Geocoder.search(address)
      ll =  results.first.coordinates
      p ll
      results = Geocoder.search ll
      p results.first.address

      url = "http://api.map.baidu.com/timezone/v1?coord_type=wgs84ll&location=#{ll[0]},#{ll[1]}&timestamp=1473130354&ak=#{baidu_key}"
      open(url) do |f|
        j = JSON.parse(f.read)
        puts JSON.pretty_generate(j)
      end
        #timezone = Timezone::Zone.new(lat: ll[0], lon: ll[1])
      #p timezone
=end