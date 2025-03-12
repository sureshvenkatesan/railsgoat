# parse Gemfile.lock directly using Ruby to generate a JSON file with the dependency tree
#
# Usage:
# ruby scripts/parse_gemfile_lock.rb
#
require 'json'

dependencies = {}
current_section = nil

File.readlines("Gemfile.lock").each do |line|
  if line.strip.empty?
    current_section = nil
  elsif line.start_with?("  ")
    gem_name, version = line.strip.split(" ")
    dependencies[current_section] ||= []
    dependencies[current_section] << { name: gem_name, version: version }
  else
    current_section = line.strip
  end
end

File.write("scripts/dependency_tree.json", JSON.pretty_generate(dependencies))
puts "Dependency tree saved to dependency_tree.json"
