#!/usr/bin/env ruby
# frozen_string_literal: true

# jiravel, a tool to view project velocity from a JIRA board

require 'net/http'
require 'uri'
require 'json'
require 'base64'
require 'date'
require 'optparse'

def load_mise_env
  mise_toml = File.join(__dir__, 'mise.toml')
  return unless File.exist?(mise_toml)

  in_env = false
  File.foreach(mise_toml) do |line|
    line = line.strip
    if line =~ /^\[([^\]]+)\]$/
      in_env = $1.strip == 'env'
    elsif in_env && (m = line.match(/^(\w+)\s*=\s*(.+)$/))
      val = m[2].strip
      val = val[1..-2] if (val.start_with?('"') && val.end_with?('"')) ||
                          (val.start_with?("'") && val.end_with?("'"))
      ENV[m[1]] = val
    end
  end
end

def parse_options
  options = { weeks_ago: 0, years_ago: 0, quiet: false }
  OptionParser.new do |opts|
    opts.banner = "Usage: jiravel PROJECT_KEY [options]"
    opts.on("--weeks-ago=N", Integer, "Target week N weeks ago (default: 0)") { |n| options[:weeks_ago] = n }
    opts.on("--years-ago=N", Integer, "Target week N years ago (default: 0)") { |n| options[:years_ago] = n }
    opts.on("-q", "--quiet", "Only print the summary line") { options[:quiet] = true }
  end.parse!
  options
end

def target_week(weeks_ago:, years_ago:)
  today  = Date.today
  year   = today.year - years_ago
  day    = [today.day, Date.new(year, today.month, -1).day].min
  anchor = Date.new(year, today.month, day) - (weeks_ago * 7)
  week_start = anchor - ((anchor.wday - 1) % 7)
  [week_start, week_start + 6]
end

def build_jql(project_key, week_start, week_end)
  "project = \"#{project_key}\" AND status changed to (\"Done\", \"Dev Complete\") " \
  "during (\"#{week_start}\", \"#{week_end}\")"
end

def build_http(jira_url)
  uri              = URI(jira_url)
  http             = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl      = uri.scheme == 'https'
  http.open_timeout = 10
  http.read_timeout = 30
  http
end

def fetch_tickets(jira_url, jql, credentials)
  uri  = URI("#{jira_url}/rest/api/3/search/jql")
  http = build_http(jira_url)

  tickets         = []
  next_page_token = nil

  loop do
    body = { jql: jql, maxResults: 100, fields: ['summary'] }
    body[:nextPageToken] = next_page_token if next_page_token

    req                  = Net::HTTP::Post.new(uri)
    req['Authorization'] = "Basic #{Base64.strict_encode64(credentials)}"
    req['Content-Type']  = 'application/json'
    req['Accept']        = 'application/json'
    req.body             = JSON.generate(body)

    res = http.request(req)
    abort("JIRA error #{res.code}: #{res.body}") unless res.is_a?(Net::HTTPSuccess)

    data = JSON.parse(res.body)
    data['issues'].each do |issue|
      tickets << { key: issue['key'], summary: issue.dig('fields', 'summary').to_s }
    end
    next_page_token = data['nextPageToken']
    break if data['issues'].empty? || !next_page_token
  end

  tickets
end

def bold(text)
  "\e[1m#{text}\e[0m"
end

def truncate(str, max)
  str.size > max ? "#{str[0, max]}..." : str
end

def print_results(tickets, quiet:)
  headline = tickets.empty? ? "No tickets completed this week." : "#{tickets.size} tickets completed this week."
  puts quiet ? headline : bold(headline)
  return if quiet || tickets.empty?
  tickets.each { |t| puts "- #{t[:key]}: #{truncate(t[:summary], 64)}" }
end


load_mise_env

options     = parse_options
project_key = ARGV[0]

abort("Usage: jiravel PROJECT_KEY [--weeks-ago=N] [--years-ago=N]") unless project_key
abort("Invalid project key") unless project_key.match?(/\A[A-Z][A-Z0-9_]+\z/i)

jira_url    = ENV.fetch('JIRA_URL')       { abort("JIRA_URL not set") }.chomp('/')
api_token   = ENV.fetch('JIRA_API_TOKEN') { abort("JIRA_API_TOKEN not set") }
email       = ENV.fetch('JIRA_EMAIL')     { abort("JIRA_EMAIL not set") }
credentials = "#{email}:#{api_token}"

week_start, week_end = target_week(weeks_ago: options[:weeks_ago], years_ago: options[:years_ago])
jql     = build_jql(project_key, week_start, week_end)
tickets = fetch_tickets(jira_url, jql, credentials)

print_results(tickets, quiet: options[:quiet])
