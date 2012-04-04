require 'rubygems'
require 'rake/gempackagetask'
require 'rake/rdoctask'

spec = Gem::Specification.new do |s|
  s.name = "chef-boundary-annotations-handler"
  s.version = "0.1"
  s.author = "joe williams"
  s.email = "j@boundary.com"
  s.homepage = "http://github.com/boundary/chef-boundary-annotations-handler"
  s.platform = Gem::Platform::RUBY
  s.summary = "Create Boundary Annotations from Chef Exceptions"
  s.files = FileList["{lib}/*"].to_a
  s.require_path = "lib"
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.md"]
  %w{json chef}.each { |gem| s.add_dependency gem }
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end

Rake::RDocTask.new do |rd|
  rd.rdoc_files.include("lib/*.rb")
end