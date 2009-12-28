require 'rubygems'
require 'spec/rake/spectask'

Spec::Rake::SpecTask.new do |t|
  t.ruby_opts = ['-I ./lib','-r rubygems']
  t.spec_opts = ['-c','-f specdoc']
  t.spec_files = FileList['test/**/*_spec.rb']
  t.warning = false
  t.rcov = true
  t.rcov_opts = ['--exclude',"json,edi4r,rcov,lib/spec,bin/spec,builder,active_"]
end