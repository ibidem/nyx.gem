Gem::Specification.new do |s|
	s.name        = 'nyx'
	s.version     = '1.1.0'
	s.date        = '2013-08-09'
	s.summary     = "project management helpers"
	s.description = "Ibidem Project Utilities"
	s.authors     = ["srcspider"]
	s.email       = 'source.spider@gmail.com'
	s.files       = ["lib/nyx.rb"]
	s.homepage    = 'http://rubygems.org/gems/nyx'
	s.license     = 'MIT'
	s.executables << 'nyx'

	# dependencies
	s.add_runtime_dependency 'git',  ['>= 1.2.6', '< 2.0']
	s.add_runtime_dependency 'json', ['>= 1.8'  , '< 2.0']
end