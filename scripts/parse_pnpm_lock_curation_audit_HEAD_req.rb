# Accepts NPM_REGISTRY_BASE_URL as a command-line argument.
# Sends a HEAD request to check if npm packages exist in the registry.
# Authenticates using an access token via the Authorization header.

# Usage:
# ruby scripts/parse_pnpm_lock_curation_audit_HEAD_req.rb "https://registry.npmjs.org" "$MY_ACCESS_TOKEN"
# ruby scripts/parse_pnpm_lock_curation_audit_HEAD_req.rb "https://$MYSERVER/npm-registry" "$MY_ACCESS_TOKEN"

require 'net/http'
require 'uri'
require 'json'

# Ensure correct usage
if ARGV.length < 2
  puts "Usage: ruby script.rb <NPM_REGISTRY_BASE_URL> <ACCESS_TOKEN>"
  exit 1
end

NPM_REGISTRY_BASE_URL = ARGV[0]
ACCESS_TOKEN = ARGV[1]

def fetch_dependencies_from_json
  dependencies = []
  unless File.exist?("scripts/pnpm_dependency_tree.json")
    puts "Error: scripts/pnpm_dependency_tree.json not found. Run parse_pnpm_lock.rb first."
    exit 1
  end

  begin
    data = JSON.parse(File.read("scripts/pnpm_dependency_tree.json"))
    # Each section is a hash: { package_name => { 'specifier' => ..., 'version' => ... } }
    ['dependencies', 'devDependencies', 'peerDependencies'].each do |section|
      if data[section]
        data[section].each do |package_name, info|
          version = info.is_a?(Hash) ? info['version'] : info
          dependencies << { name: package_name, version: version, type: section }
        end
      end
    end
  rescue => e
    puts "Error reading dependency tree JSON: #{e.message}"
    exit 1
  end
  dependencies
end

def check_npm_registry(package_name, package_version, package_type)
  # NPM registry URL format: https://registry.npmjs.org/package-name/version
  package_url = "#{NPM_REGISTRY_BASE_URL}/#{package_name}/#{package_version}"
  uri = URI.parse(package_url)

  request = Net::HTTP::Head.new(uri)
  request['Authorization'] = "Bearer #{ACCESS_TOKEN}" unless ACCESS_TOKEN.empty?

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == "https")

  begin
    response = http.request(request)

    case response.code.to_i
    when 200
      puts "#{package_name}@#{package_version} (#{package_type}) ✅ Available in NPM Registry"
    when 403
      puts "#{package_name}@#{package_version} (#{package_type}) ❌ Blocked (403 Forbidden)"
    when 404
      puts "#{package_name}@#{package_version} (#{package_type}) ❌ Not Found (404)"
    else
      puts "#{package_name}@#{package_version} (#{package_type}) ⚠️ Unexpected Response: #{response.code}"
    end

  rescue StandardError => e
    puts "#{package_name}@#{package_version} (#{package_type}) ❌ Request Failed"
    puts "Exception: #{e.message}"
  end
end

dependencies = fetch_dependencies_from_json
puts "Checking #{dependencies.length} dependencies..."

dependencies.each do |dep|
  check_npm_registry(dep[:name], dep[:version], dep[:type])
end 