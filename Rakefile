require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'
RuboCop::RakeTask.new

task default: :spec

desc 'Update Library Files'
task :update_library_files do
  puts 'Updating Library Files'
  
  require 'fileutils'

  lib_files = []
  $:.each do |load_path|
    if /topolys/.match(load_path)
      lib_files = Dir.glob(File.join(load_path, 'topolys/*.rb'))
    end
  end
  
  schema_files = Dir.glob(File.join(File.dirname(__FILE__), './lib/topolys_measures/schema/*.json'))
  measure_resources = Dir.glob(File.join(File.dirname(__FILE__), './lib/measures/*/resources'))

  schema_files.each do |schema_file|
    measure_resources.each do |measure_resource|
      FileUtils.cp(schema_file, "#{measure_resource}/.")
    end
  end

  lib_files.each do |lib_file|
    measure_resources.each do |measure_resource|
      FileUtils.cp(lib_file, "#{measure_resource}/.")
    end
  end
end

task :spec => [:update_library_files]
