require 'net/http'
require 'nokogiri'
require 'advanced_query_builder'

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

  def search_for_barcode(barcode)
    query = AdvancedQueryBuilder.new
    query.and('barcode_u_sstr', barcode)
    url = "/repositories/#{JSONModel.repository}/top_containers/search"
    uri = URI.join(AppConfig[:backend_url], url)
    uri.query = URI.encode_www_form({:filter => query.build.to_json})

    response = HTTPRequest.new.get(uri)
    if response.is_a?(Net::HTTPSuccess)
      obj = JSON.parse(response.body)
      top_container = obj['response']['docs'][0]['uri']

      return top_container
    else
      return "Barcode search error"
    end
  end

  def item_search(mms)
    uri = URI("#{@base_url}#{mms}/holdings/ALL/items")
    uri.query = URI.encode_www_form({:apikey => @key, :format => 'json'})
    response = HTTPRequest.new.get(uri, :use_ssl => true)

    items = []
    if response.is_a?(Net::HTTPSuccess)
      obj = JSON.parse(response.body)
      if obj['total_record_count'] > 0
        obj['item'].each do |item|
          item_data = item['item_data']
          i = {
            'pid' => item_data['pid'],
            'barcode' => item_data['barcode'],
            'top_container' => search_for_barcode(item_data['barcode']),
            'description' => item_data['description'],
            'location' => item_data['location']['value'],
            'profile' => item_data['internal_note_2']
          }

          items.push(i)
        end
      end
    end

    items
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
