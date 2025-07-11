# Accepts ARTIFACTORY_BASE_URL as a command-line argument.
# Sends a HEAD request instead of a GET request.
# Authenticates using an access token via the Authorization header.

# Usage:
# ruby scripts/parse_gemfile_lock_curation_audit_HEAD_req.rb "https://example.jfrog.io/artifactory/api/gems/cg-lab-ruby-gems-remote/gems" "$MY_ACCESS_TOKEN"

# ruby scripts/parse_gemfile_lock_curation_audit_HEAD_req.rb "https://$MYSERVER/artifactory/api/gems/cg-lab-ruby-gems-remote/gems" "$MY_ACCESS_TOKEN"


require 'net/http'
require 'uri'
require 'json'

# Ensure correct usage
if ARGV.length < 2
  puts "Usage: ruby script.rb <ARTIFACTORY_BASE_URL> <ACCESS_TOKEN>"
  exit 1
end

ARTIFACTORY_BASE_URL = ARGV[0]
ACCESS_TOKEN = ARGV[1]

def fetch_dependencies
  dependencies = []
  in_dependencies = false

  File.readlines("Gemfile.lock").each do |line|
    if line.strip.empty?
      in_dependencies = false
    elsif in_dependencies
      match = line.strip.match(/^(\S+) \(([\d.]+)\)/)
      dependencies << { name: match[1], version: match[2] } if match
    elsif line.strip == "GEM"
      in_dependencies = true
    end
  end

  dependencies
end

def check_artifactory(gem_name, gem_version)
  gem_filename = "#{gem_name}-#{gem_version}.gem"
  gem_url = "#{ARTIFACTORY_BASE_URL}/#{gem_filename}"
  uri = URI.parse(gem_url)

  request = Net::HTTP::Head.new(uri)
  request['Authorization'] = "Bearer #{ACCESS_TOKEN}"

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == "https")

  begin
    response = http.request(request)

    case response.code.to_i
    when 200
      puts "#{gem_name} #{gem_version} ✅ Available in Artifactory"
    when 403
      puts "#{gem_name} #{gem_version} ❌ Blocked (403 Forbidden)"
    when 404
      puts "#{gem_name} #{gem_version} ❌ Not Found (404)"
    else
      puts "#{gem_name} #{gem_version} ⚠️ Unexpected Response: #{response.code}"
    end

  rescue StandardError => e
    puts "#{gem_name} #{gem_version} ❌ Request Failed"
    puts "Exception: #{e.message}"
  end
end

dependencies = fetch_dependencies
dependencies.each do |dep|
  check_artifactory(dep[:name], dep[:version])
end
