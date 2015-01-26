# encoding: utf-8

require 'rubygems'
require 'bundler'
require 'pathname'

gem_path  = Pathname.new(__FILE__).dirname
lib_path  = gem_path + 'lib'
task_path = lib_path + 'tasks'
task_glob = task_path + '**' + '*.rake'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://guides.rubygems.org/specification-reference/ for more options
  gem.name = "pdba"
  gem.homepage = "http://github.com/rabbitt/pdba"
  gem.license = "MIT"
  gem.summary = %Q{puppetdb aggregation proxy and query api tool}
  gem.description = %Q{TODO: longer description of your gem}
  gem.email = "rabbitt@gmail.com"
  gem.authors = ["Carl P. Corliss"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

desc "Code coverage detail"
task :simplecov do
  ENV['COVERAGE'] = "true"
  Rake::Task['test'].execute
end

task :default => :test

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "pdba #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

require 'warbler'
Warbler::Task.new

Dir[task_glob.to_s].each { |file| load file }