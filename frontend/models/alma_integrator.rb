require 'net/http'
require 'nokogiri'
require 'advanced_query_builder'

class AlmaIntegrator

  def initialize(baseurl, key)
    @baseurl = baseurl
    @key = key
  end

  def search_bibs(mms)
    uri = URI("#{@baseurl}/#{mms}")
    uri.query = URI.encode_www_form({:apikey => @key})
    response = HTTPRequest.new.get(uri, :use_ssl => true)

    response.is_a?(Net::HTTPSuccess) ? true : false
  end

  def search_holdings(mms)
    results = { 'holdings' => [] }

    uri = URI("#{@baseurl}/#{mms}/holdings")
    uri.query = URI.encode_www_form({:apikey => @key, :format => 'json'})
    response = HTTPRequest.new.get(uri, :use_ssl => true)

    if response.is_a?(Net::HTTPSuccess)
			obj = JSON.parse(response.body)
			results['count'] = obj['total_record_count']
			if results['count'] > 0
				holdings = obj['holding']
				holdings.each do |holding|
					h = {
						'id' => holding['holding_id'],
						'code' => holding['location']['value'],
						'name' => holding['location']['desc']
					}

					results['holdings'].push(h)
				end
			end
		end

		results
  end

  def get_aspace_item_data(barcode)
		aq = AdvancedQueryBuilder.new
		aq.and('barcode_u_sstr', barcode)
		url = "#{JSONModel(:top_container).uri_for("")}/search"
		obj = JSONModel::HTTP::get_json(url, {'filter' => aq.build.to_json})
		obj['response']['docs'][0]
	end

  def search_items(mms,page=1)
		results = { 'page' => page, 'items' => [] }

		uri = URI("#{@baseurl}/#{mms}/holdings/ALL/items")
		uri.query = URI.encode_www_form({:apikey => @key, :format => 'json'})
		response = HTTPRequest.new.get(uri, :use_ssl => true)

		if response.is_a?(Net::HTTPSuccess)
			obj = JSON.parse(response.body)
			results['count'] = obj['total_record_count']
      results['last_page'] = obj['total_record_count'].round(-1) / 10
			if results['count'] > 0
				items = obj['item']
				items.each do |item|
					item_data = item['item_data']
					as_item_data = get_aspace_item_data(item_data['barcode'])
					as_profile = as_item_data['container_profile_display_string_u_sstr'][0].partition('[').first.rstrip
					i = {
						'pid' => item_data['pid'],
            'barcode' => item_data['barcode'],
            'description' => item_data['description'],
            'location' => item_data['location']['value'],
						'alma_profile' => item_data['internal_note_2'],
						'as_profile' => as_profile,
						'top_container' => as_item_data['uri']
					}

					results['items'].push(i)
				end
			end
		end

		results
	end

  def post_bib(mms, data)
    if mms.nil?
      uri = URI(@baseurl)
      uri.query = URI.encode_www_form({:apikey => @key})
      response = HTTPRequest.new.post(uri, data, :use_ssl => true)
    else
      uri = URI("#{@baseurl}/#{mms}")
      uri.query = URI.encode_www_form({:apikey => @key})
      response = HTTPRequest.new.put(uri, data, :use_ssl => true)
    end

    response
  end

  def post_holding(mms, data)
    uri = URI("#{@baseurl}/#{mms}/holdings")
    uri.query = URI.encode_www_form({:apikey => @key})
    response = HTTPRequest.new.post(uri, data, :use_ssl => true)

    response
  end
end
