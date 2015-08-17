require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
end

require 'rdoc/task'
namespace :doc do
  RDoc::Task.new do |rd|
    rd.rdoc_dir = 'doc'
    rd.rdoc_files.include('lib/**/*.rb')
  end
end

task :default => :test
