require 'rake'
begin
  $: << File.join(File.dirname(__FILE__),'lib')
  require 'openils/mapper'
  Gem::Specification.new do |s|
    s.name = "openils-mapper"
    s.version = OpenILS::Mapper::VERSION
    s.summary = "EDIFACT<->JSON middleware for the Evergreen Open Source ILS"
    s.email = "mbklein@gmail.com"
    s.description = "Middleware layer to provide translation between high-level JSON and raw EDIFACT messages"
    s.authors = ["Michael B. Klein"]
    s.files = FileList["[A-Z]*", "README.rdoc", "{bin,lib,test}/**/*"]
    s.extra_rdoc_files = ['README.rdoc']
    s.rdoc_options << '--main' << 'README.rdoc'
    s.add_dependency 'edi4r', '>= 0.9.4'
    s.add_dependency 'edi4r-tdid', '>= 0.6.5'
    s.add_dependency 'json', '>= 1.1.3'
    s.add_development_dependency 'rcov', '>= 0.8.1'
    s.add_development_dependency 'rspec', '>= 1.2.2'
    s.add_development_dependency 'rake', '>= 0.8.0'
  end
rescue LoadError
  puts "Error loading OpenILS::Mapper module."
end
