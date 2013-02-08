#!/usr/bin/env ruby

require 'httparty'
require 'json'
require 'net/http'
require 'sinatra'

set :port, 8042

## config
CONFIG = YAML.load_file('config.yml')
TOKEN = CONFIG["token"] || "unconfigured"
CAUSE = CONFIG["cause"] || "git_commit_triggered"
SERVER = CONFIG["server"] || "https://jenkins/"


## helper functions
def trigger_job(job, branch)
  uri = URI("#{SERVER}job/#{job}/buildWithParameters")

  req = Net::HTTP::Post.new(uri.path)
  req.set_form_data('token'  => TOKEN,
                    'cause'  => CAUSE,
                    'branch' => branch)

  res = Net::HTTP.start(uri.host, uri.port,
                        :use_ssl => uri.scheme == 'https',
                        :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
    http.request(req)
    end

  case res
  when Net::HTTPSuccess, Net::HTTPRedirection
    p "OK"
  else
    res.value
  end
end


def job_names
  json = HTTParty.get("#{SERVER}/api/json")
  json["jobs"].map {|job| job["name"]}
end


def job_details(job_name)
  HTTParty.get("#{SERVER}/job/#{job_name}/api/json")
end


def build_details(job_name, build_number)
  HTTParty.get("#{SERVER}/job/#{job_name}/#{build_number}/api/json")
end

## main sinatra app

# this is where GitHub actually ends up at, configured as
# WebHook URL at https://github.com/$OWNER/$PROJECT/settings/hooks
post '/trigger' do
  push = JSON.parse(params[:payload])
  # p "JSON data: #{push.inspect}"
  # p JSON.pretty_generate(push)

  project = push["repository"]["name"]
  project = project + "-source" # we use $job-source as default entry point
  branch = push["ref"]

  # make sure we do not trigger a build with a branch that was just deleted
  deleted = push["deleted"]

  if deleted
    puts "branch #{branch} was deleted, not triggering build"
  elsif job_names.include? project
    trigger_job(project, branch)
  else
    puts "no such job #{project}"
  end
end

# debugging helper
post '/debug' do
  puts params[:payload]
end

## END OF FILE #################################################################
