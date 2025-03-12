#Accepts ARTIFACTORY_BASE_URL and ACCESS_TOKEN as parameters.
# Sends a GET request to download the .gem files instead of a HEAD request.
# Saves the downloaded gems in a downloaded_gems directory.
# Creates the directory if it doesn't exist.

#Usage:
# ruby scripts/parse_gemfile_lock_curation_audit_DOWNLOAD_req.rb "https://your.artifactory.instance/api/gems/ruby-gems-repo/gems" "$MY_ACCESS_TOKEN"

# ruby scripts/parse_gemfile_lock_curation_audit_DOWNLOAD_req.rb "https://$MYSERVER/artifactory/api/gems/cg-lab-ruby-gems-remote/gems" "$MY_ACCESS_TOKEN"

require 'net/http'
require 'uri'
require 'fileutils'

# Ensure correct usage
if ARGV.length < 2
  puts "Usage: ruby script.rb <ARTIFACTORY_BASE_URL> <ACCESS_TOKEN>"
  exit 1
end

ARTIFACTORY_BASE_URL = ARGV[0]
ACCESS_TOKEN = ARGV[1]
DOWNLOAD_DIR = "scripts/downloaded_gems"

# Create directory if it doesn't exist
FileUtils.mkdir_p(DOWNLOAD_DIR)

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

def download_gem(gem_name, gem_version)
  gem_filename = "#{gem_name}-#{gem_version}.gem"
  gem_url = "#{ARTIFACTORY_BASE_URL}/#{gem_filename}"
  uri = URI.parse(gem_url)

  request = Net::HTTP::Get.new(uri)
  request['Authorization'] = "Bearer #{ACCESS_TOKEN}"

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == "https")

  response = http.request(request)

  case response.code.to_i
  when 200
    File.open(File.join(DOWNLOAD_DIR, gem_filename), "wb") do |file|
      file.write(response.body)
    end
    puts "#{gem_name} #{gem_version} ✅ Downloaded successfully"
  when 403
    puts "#{gem_name} #{gem_version} ❌ Blocked (403 Forbidden)"
    puts "Error Message: #{response.body}" unless response.body.empty?
  when 404
    puts "#{gem_name} #{gem_version} ❌ Not Found (404)"
  else
    puts "#{gem_name} #{gem_version} ⚠️ Unexpected Response: #{response.code}"
    puts "Response Body: #{response.body}" unless response.body.empty?
  end
end

dependencies = fetch_dependencies
dependencies.each do |dep|
  download_gem(dep[:name], dep[:version])
end
