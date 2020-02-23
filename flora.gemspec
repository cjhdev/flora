require File.expand_path("../lib/flora/version", __FILE__)
require 'date'

Gem::Specification.new do |s|

  s.name    = "flora"
  s.version = Flora::VERSION
  s.date = Date.today.to_s
  s.summary = "A LoRaWAN Network Server"
  s.author  = "Cameron Harper"
  s.email = "contact@cjh.id.au"
  s.files = Dir.glob("lib/**/*.rb")
  s.license = 'MIT'
  s.test_files = Dir.glob("test/**/*_test.rb")
  s.homepage = "https://github.com/cjhdev/flora"
  
  s.add_development_dependency 'rake'
  s.add_development_dependency 'minitest'        
  s.add_development_dependency 'fakeredis'      
  s.add_development_dependency 'redis'      
  
  s.required_ruby_version = '>= 2.0'
  
end
