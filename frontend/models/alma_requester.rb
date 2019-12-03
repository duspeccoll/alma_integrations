require 'net/http'

# convenience class for making API requests
#
# despite the name, it is also used for making GET requests of the ArchivesSpace API

class AlmaRequester

  def get(uri, opts = {})
    response = Net::HTTP.start(uri.host, uri.port, opts) do |http|
			req = Net::HTTP::Get.new(uri)
			req['X-ArchivesSpace-Session'] = Thread.current[:backend_session] if uri.to_s.start_with?("#{AppConfig[:backend_url]}")
			http.request(req)
		end

		response
  end

  def post(uri, data, opts = {})
    response = Net::HTTP.start(uri.host, uri.port, opts) do |http|
			req = Net::HTTP::Post.new(uri)
			req.body = data
			req.content_type = 'application/xml'
			http.request(req)
		end

		response
  end

  def put(uri, data, opts = {})
    response = Net::HTTP.start(uri.host, uri.port, opts) do |http|
			req = Net::HTTP::Put.new(uri)
			req.body = data
			req.content_type = 'application/xml'
			http.request(req)
		end

		response
  end
end
