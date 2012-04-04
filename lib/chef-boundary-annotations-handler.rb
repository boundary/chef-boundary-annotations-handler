require 'rubygems'
require 'chef'
require 'chef/handler'
require 'net/http'
require 'net/https'
require 'uri'
require 'json'

class BoundaryAnnotations < Chef::Handler

  #
  # Some of this code was borrowed from https://github.com/portertech/chef-irc-snitch
  #

  def initialize(boundary_orgid, boundary_apikey, github_user, github_token)
    @boundary_orgid = boundary_orgid
    @boundary_apikey = boundary_apikey
    @github_user = github_user
    @github_token = github_token
  end

  def fmt_run_list
    run_status.node.run_list.map {|r| r.type == :role ? r.name : r.to_s }.join(', ')
  end

  def fmt_fail_gist
    ([ "run_status.node: #{run_status.node.name} (#{run_status.node.ipaddress})",
       "Run list: #{run_status.node.run_list}",
       "All roles: #{run_status.node.roles.join(', ')}",
       "",
       "#{run_status.formatted_exception}",
       ""] +
     Array(backtrace)).join("\n")
  end

  def fmt_success_gist
    [ "run_status.node: #{run_status.node.name} (#{run_status.node.ipaddress})",
      "Run list: #{run_status.node.run_list}",
      "All roles: #{run_status.node.roles.join(', ')}",
      "",
      "Changes made:",
      "#{run_status.updated_resources.join("\n")}",
      ""].join("\n")
  end

  def report

    if run_status.success?
      if run_status.updated_resources.length.to_i > 0
        tags = ["chef", "success"]

        gist = fmt_success_gist

        Chef::Log.info("Chef run suceeded with #{run_status.updated_resources.length.to_i} changes @ #{run_status.end_time}, creating Boundary Annotation")

        gist_id = create_gist(gist, "succeeded")
        annotation_url = create_annotation(gist_id, tags, "Chef")
      end
    end

    if run_status.failed?
      tags = ["chef", "failure", "exception", run_status.exception]

      gist = fmt_fail_gist

      Chef::Log.error("Chef run failed @ #{run_status.end_time}, creating Boundary Annotation")
      Chef::Log.error("#{run_status.formatted_exception}")

      gist_id = create_gist(gist, "failed")
      annotation_url = create_annotation(gist_id, tags, "Chef Exception")
    end

  end

  def create_gist(gist, type)
    gist_id = nil
    begin
      timeout(10) do
        url = "http://gist.github.com/api/v1/json/new"

        res = Net::HTTP.post_form(URI.parse(url), {
          "files[#{run_status.node.name}-#{run_status.end_time.to_i.to_s}]" => gist,
          "login" => @github_user,
          "token" => @github_token,
          "description" => "Chef run #{type} on #{run_status.node.name} @ #{run_status.end_time}",
          "public" => false
        })

        bad_response?(:post, url, res)

        gist_id = JSON.parse(res.body)["gists"].first["repo"]
        Chef::Log.info("Created a GitHub Gist @ https://gist.github.com/#{gist_id}")
        gist_id
      end
    rescue Timeout::Error
      Chef::Log.error("Timed out while attempting to create a GitHub Gist")
    end
  end

  def create_annotation(gist_id, tags, type)
    auth = auth_encode("#{@boundary_apikey}:")
    headers = {"Authorization" => "Basic #{auth}", "Content-Type" => "application/json"}

    annotation = {
      :type => type,
      :subtype => run_status.node.name,
      :start_time => run_status.start_time.to_i,
      :end_time => run_status.end_time.to_i,
      :tags => tags,
      :links => [
        {
         "rel" => "output",
         "href" => "https://gist.github.com/#{gist_id}",
         "note" => "gist"
        }
      ]
    }

    annotation_json = annotation.to_json

    uri = URI("https://api.boundary.com/#{@boundary_orgid}/annotations")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ca_file = "#{File.dirname(__FILE__)}/cacert.pem"
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    begin
      timeout(10) do
        req = Net::HTTP::Post.new(uri.request_uri)
        req.body = annotation_json

        headers.each{|k,v|
          req[k] = v
        }

        res = http.request(req)

        bad_response?(:post, uri.request_uri, res)

        Chef::Log.info("Created a Boundary Annotation @ #{res["location"]}")
        res["location"]
      end
    rescue Timeout::Error
      Chef::Log.error("Timed out while attempting to create Boundary Annotation")
    end
  end

  def auth_encode(creds)
    auth = Base64.encode64(creds).strip
    auth.gsub("\n","")
  end

  def bad_response?(method, url, response)
    case response
    when Net::HTTPSuccess
      false
    else
      true
      Chef::Log.error("Got a #{response.code} for #{method} to #{url}")
    end
  end

end
