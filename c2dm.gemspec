# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "c2dm"
  s.version     = "0.2.4"
  s.authors     = ["Amro Mousa", "Keenan Brock"]
  s.email       = ["keenan@thebrocks.net"]
  s.homepage    = "http://github.com/ping4/c2dm"
  s.summary     = %q{sends push notifications to Android devices}
  s.description = %q{c2dm sends push notifications to Android devices via google c2dm. c2dm upgraded to gcm, this gem still uses c2dm}
  s.license     = "MIT"
  
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency('net-http-persistent')
  s.add_development_dependency('rspec')
end
