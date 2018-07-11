require 'net/http'
require 'nokogiri'

class AlmaIntegrator

  def initialize(base_url, key)
    @base_url = base_url
    @key = key
  end

  def bib_search(mms)
    uri = URI("#{@base_url}#{mms}")
    uri.query = URI.encode_www_form({:apikey => @key})
    response = HTTPRequest.new.get(uri, :use_ssl => true)

    response.is_a?(Net::HTTPSuccess) ? true : false
  end

  def holding_search(mms)
    uri = URI("#{@base_url}#{mms}/holdings")
    uri.query = URI.encode_www_form({:apikey => @key, :format => 'json'})
    response = HTTPRequest.new.get(uri, :use_ssl => true)

    holdings = []
		if response.is_a?(Net::HTTPSuccess)
			obj = JSON.parse(response.body)
			if obj['total_record_count'] > 0
				obj['holding'].each do |holding|
					h = {
						'id' => holding['holding_id'],
						'code' => holding['location']['value'],
						'name' => holding['location']['desc']
					}
					holdings.push(h)
				end
			end
		end
		holdings
  end

  def post_bib(mms, data)
    if mms.nil?
      uri = URI(@base_url)
      uri.query = URI.encode_www_form({:apikey => @key})
      response = HTTPRequest.new.post(uri, data, :use_ssl => true)
    else
			uri = URI("#{@base_url}#{mms}")
			uri.query = URI.encode_www_form({:apikey => @key})
			response = HTTPRequest.new.put(uri, data, :use_ssl => true)
		end

    response
  end

  def post_holding(mms, data)
    uri = URI("#{@base_url}#{mms}/holdings")
    uri.query = URI.encode_www_form({:apikey => @key})
    response = HTTPRequest.new.post(uri, data, :use_ssl => true)

    response
  end

end
