require 'net/http'
require 'nokogiri'
require 'advanced_query_builder'

class AlmaIntegrator

  def initialize(baseurl, key)
    @baseurl = baseurl
    @key = key
  end

  def get_archivesspace_bib(ref)
    aspace = {}
    uri = URI("#{JSONModel::HTTP.backend_url}#{ref.gsub(/(\d+)$/,'marc21/\1.xml')}")
    response = AlmaRequester.new.get(uri)
    if response.is_a?(Net::HTTPSuccess)
      xml = Nokogiri::XML(response.body,&:noblanks)
      aspace['content'] = xml.at_css('record')
    else
      aspace['error'] = JSON.parse(response.body)['error']
    end

    return aspace
  end

  def get_alma_bib(mms)
    alma = {}

    if mms.nil?
      alma['error'] = I18n.t("plugins.alma_integrations.errors.no_mms")
    else
      uri = URI("#{@baseurl}/#{mms}")
      uri.query = URI.encode_www_form({:apikey => @key})
      response = AlmaRequester.new.get(uri, :use_ssl => true)
      xml = Nokogiri::XML(response.body,&:noblanks)
      if response.is_a?(Net::HTTPSuccess)
        alma['content'] = xml.at_css('record')
      else
        alma['error'] = "[#{xml.at_css('errorCode').text}] #{xml.at_css('errorMessage').text}"
      end
    end

    alma
  end

  def sync_bibs(aspace, alma)
    aspace_008 = aspace['content'].at_css('controlfield[@tag="008"]')
    alma_008 = alma['content'].at_css('controlfield[@tag="008"]')

    if aspace_008.text[0,6] != alma_008.text[0,6]
      controlfield_string = alma_008.text[0,6]
      controlfield_string += aspace_008.text[6..-1]
      aspace['content'].at_css('controlfield[@tag="008"]').content = controlfield_string
    end

    return aspace['content'].to_xml(indent: 2)
  end

  def search_bibs(ref, mms)
    results = {'mms' => mms}

    # first, try to get the ArchivesSpace MARC record
    # next, try to get the Alma MARC record
    # last, compare them to see if any changes need to be made before overlay
    # (e.g. bringing over Alma's 008/0-5 for date on file)

    aspace = get_archivesspace_bib(ref)
    if aspace.has_key?('error')
      results['aspace'] = {'error' => aspace['error']}
      results['alma'] = {'error' => I18n.t("plugins.alma_integrations.errors.no_marc")}
    else
      results['aspace'] = {'success' => ref}
      alma = get_alma_bib(mms)
      if alma.has_key?('error')
        results['alma'] = {'error' => alma['error']}
        results['marc'] = aspace['content'].to_xml(indent: 2)
      else
        results['alma'] = {'success' => mms}
        results['marc'] = sync_bibs(aspace, alma)
      end
    end

    results
  end

  def search_holdings(mms)
    results = { 'holdings' => [] }

    return if mms.nil?

    uri = URI("#{@baseurl}/#{mms}/holdings")
    uri.query = URI.encode_www_form({:apikey => @key, :format => 'json'})
    response = AlmaRequester.new.get(uri, :use_ssl => true)

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
    item_data = {}

		aq = AdvancedQueryBuilder.new
		aq.and('barcode_u_sstr', barcode)
		url = "#{JSONModel(:top_container).uri_for("")}/search"
		obj = JSONModel::HTTP::get_json(url, {'filter' => aq.build.to_json})

    item = obj['response']['docs'].first
    return item_data if item.nil?

    unless item['container_profile_display_string_u_sstr'].nil?
      item_data['profile'] = item['container_profile_display_string_u_sstr'].first
        .partition('[')
        .first
        .rstrip
    end
    item_data['top_container'] = item['uri'] unless item['uri'].nil?

    return item_data
	end

  def search_items(mms,page)
    results = { 'page' => page, 'offset' => (page - 1) * 10, 'items' => [] }

		uri = URI("#{@baseurl}/#{mms}/holdings/ALL/items")
		uri.query = URI.encode_www_form({:apikey => @key, :format => 'json', :offset => results['offset']})
		response = AlmaRequester.new.get(uri, :use_ssl => true)

		if response.is_a?(Net::HTTPSuccess)
			obj = JSON.parse(response.body)
			results['count'] = obj['total_record_count']
      results['last_page'] = obj['total_record_count'].round(-1) / 10
			if results['count'] > 0
				items = obj['item']
				items.each do |item|
					item_data = item['item_data']
					as_item_data = get_aspace_item_data(item_data['barcode'])
					i = {
						'pid' => item_data['pid'],
            'barcode' => item_data['barcode'],
            'description' => item_data['description'],
            'location' => item_data['location']['value'],
						'alma_profile' => item_data['internal_note_2'],
						'as_profile' => as_item_data['profile'],
						'top_container' => as_item_data['top_container']
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
      response = AlmaRequester.new.post(uri, data, :use_ssl => true)
    else
      uri = URI("#{@baseurl}/#{mms}")
      uri.query = URI.encode_www_form({:apikey => @key})
      response = AlmaRequester.new.put(uri, data, :use_ssl => true)
    end

    response
  end

  def post_holding(mms, data)
    uri = URI("#{@baseurl}/#{mms}/holdings")
    uri.query = URI.encode_www_form({:apikey => @key})
    response = AlmaRequester.new.post(uri, data, :use_ssl => true)

    response
  end
end
