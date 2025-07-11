# parse pnpm-lock.yaml directly using Ruby to generate a JSON file with the dependency tree
#
# Usage:
# ruby scripts/parse_pnpm_lock.rb
#
require 'json'
require 'yaml'

def parse_pnpm_lock
  result = {}
  unless File.exist?("pnpm-lock.yaml")
    puts "Error: pnpm-lock.yaml not found in current directory"
    exit 1
  end

  begin
    lock_data = YAML.load_file("pnpm-lock.yaml")
    importers = lock_data['importers'] || {}
    root = importers['.'] || {}
    result['dependencies'] = root['dependencies'] || {}
    result['devDependencies'] = root['devDependencies'] || {}
    result['peerDependencies'] = root['peerDependencies'] || {}
  rescue => e
    puts "Error parsing pnpm-lock.yaml: #{e.message}"
    exit 1
  end
  result
end

dependencies = parse_pnpm_lock
File.write("scripts/pnpm_dependency_tree.json", JSON.pretty_generate(dependencies))
puts "PNPM dependency tree saved to scripts/pnpm_dependency_tree.json" 