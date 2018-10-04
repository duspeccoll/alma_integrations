require 'advanced_query_builder'

class AlmaIntegrationsController < ApplicationController

	set_access_control "view_repository" => [:index, :search, :add_bibs, :add_holdings]

	def index
	end

	def search
		results = perform_search(params['resource']['ref'])
		render_aspace_partial :partial => "alma_integrations/results", :locals => {:results => results}
	end

	def add_bibs
		post_bibs(params)
	end

	def add_holdings
		post_holdings(params)
	end

	private

	def get_request(uri, opts = {})
		resp = Net::HTTP.start(uri.host, uri.port, opts) do |http|
			req = Net::HTTP::Get.new(uri)
			req['X-ArchivesSpace-Session'] = Thread.current[:backend_session] if uri.to_s.start_with?("#{AppConfig[:backend_url]}")
			http.request(req)
		end

		resp
	end

	def post_request(uri, data, opts = {})
		resp = Net::HTTP.start(uri.host, uri.port, opts) do |http|
			req = Net::HTTP::Post.new(uri)
			req.body = data
			req.content_type = 'application/xml'
			http.request(req)
		end

		resp
	end

	def put_request(uri, data, opts = {})
		resp = Net::HTTP.start(uri.host, uri.port, opts) do |http|
			req = Net::HTTP::Put.new(uri)
			req.body = data
			req.content_type = 'application/xml'
			http.request(req)
		end

		resp
	end

	def search_bibs(mms)
		uri = URI("#{AppConfig[:alma_api_url]}/#{mms}")
		uri.query = URI.encode_www_form({:apikey => AppConfig[:alma_apikey]})
		resp = get_request(uri, :use_ssl => true)

		resp.is_a?(Net::HTTPSuccess) ? true : false
	end

	def search_holdings(mms)
		holdings = []

		uri = URI("#{AppConfig[:alma_api_url]}/#{mms}/holdings")
		uri.query = URI.encode_www_form({:apikey => AppConfig[:alma_apikey], :format => 'json'})
		resp = get_request(uri, :use_ssl => true)

		if resp.is_a?(Net::HTTPSuccess)
			obj = JSON.parse(resp.body)
			if obj['total_record_count'] > 0
				results = obj['holding']
				results.each do |result|
					h = {
						'id' => result['holding_id'],
						'code' => result['location']['value'],
						'name' => result['location']['desc']
					}
					holdings.push(h)
				end
			end
		end

		holdings
	end

	def search_for_barcode(barcode)
		params = params_for_backend_search

		aq = AdvancedQueryBuilder.new
		aq.and('barcode_u_sstr', barcode)
		url = "#{JSONModel(:top_container).uri_for("")}/search"
		params = params.merge({"filter" => aq.build.to_json})

		obj = JSONModel::HTTP::get_json(url, params)
		top_container = obj['response']['docs'][0]['uri']
	end

	def search_items(mms)
		items = []

		uri = URI("#{AppConfig[:alma_api_url]}/#{mms}/holdings/ALL/items")
		uri.query = URI.encode_www_form({:apikey => AppConfig[:alma_apikey], :format => 'json'})
		resp = get_request(uri, :use_ssl => true)

		if resp.is_a?(Net::HTTPSuccess)
			obj = JSON.parse(resp.body)
			if obj['total_record_count'] > 0
				results = obj['item']
				results.each do |result|
					item_data = result['item_data']
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

	def perform_search(ref)
		json = JSONModel::HTTP::get_json(ref)
		response = {
			'title' => json['title'],
			'id' => json['id_0'],
			'count' => 0,
			'ref' => ref,
			'results' => []
		}

		if json['user_defined'].nil? or json['user_defined']['string_2'].nil?
			return response
		else
			response['mms'] = json['user_defined']['string_2']
		end

		response['bib_found'] = search_bibs(response['mms'])
		response['holdings'] = search_holdings(response['mms'])
		response['items'] = search_items(response['mms'])

		response
	end

	def update_resource(ref, mms)
		obj = JSONModel::HTTP.get_json(ref)
		if obj['user_defined'].nil?
			obj['user_defined'] = { 'string_2' => mms }
		else
			obj['user_defined']['string_2'] = mms
		end

		uri = URI("#{JSONModel::HTTP.backend_url}#{ref}")
		response = JSONModel::HTTP.post_json(uri, obj.to_json)
	end

	def build_bibs(params)
		marc_url = URI.join(AppConfig[:backend_url], params['ref'].gsub(/(\d+?)$/, 'marc21/\1.xml'))
		resp = get_request(marc_url, {'auth' => true})

		marc = Nokogiri::XML(resp.body)

		# Nokogiri won't put 'standalone' in the header so you have to do it yourself'
		header = Nokogiri::XML('<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>')
		doc = Nokogiri::XML::Builder.with(header) { |xml| xml.bib }.to_xml
		data = Nokogiri::XML(doc)
		if params['mms']
			mms_id = Nokogiri::XML::Node.new('mms_id', data)
			mms_id.content = params['mms']
			data.root.add_child(mms_id)
		end

		data.root.add_child(marc.at_css('record'))

		data.to_xml
	end

	def post_bibs(params)
		data = build_bibs(params)

		if params['mms'].nil?
			url = "#{AppConfig[:alma_api_url]}"
		else
			url = "#{AppConfig[:alma_api_url]}/#{params['mms']}"
		end
		uri = URI(url)
		uri.query = URI.encode_www_form({:apikey => AppConfig[:alma_apikey]})

		if params['mms'].nil?
			resp = post_request(uri, data, :use_ssl => true)
		else
			resp = put_request(uri, data, :use_ssl => true)
		end

		if resp.is_a?(Net::HTTPSuccess)
			doc = Nokogiri::XML(resp.body)
			mms = doc.at_css('mms_id').text
			if params['mms'].nil?
				flash[:success] = "BIB created. MMS ID: #{mms}"
				jsonresp = update_resource(params['ref'], mms)
				if jsonresp.is_a?(Net::HTTPSuccess)
					flash[:success] += ". MMS ID added to Resource"
				else
					flash[:error] = "Error: Couldn't add MMS ID to Resource"
				end
			else
				flash[:success] = "BIB updated. MMS ID: #{mms}"
			end
		else
			#flash[:error] = "Error: #{doc.at_css('errorMessage').text} (#{doc.at_css('errorCode').text})"
			flash[:error] = "Error: #{resp.body}, calling #{url}"
		end

		redirect_to :action => :index
	end

	def build_holdings(params)
		controlfield_string = Time.now.strftime("%y%m%d")
		controlfield_string += "2u^^^^8^^^4001uueng0000000"

		# Nokogiri won't put 'standalone' in the header so you have to do it yourself
		doc = Nokogiri::XML('<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>')
		builder = Nokogiri::XML::Builder.with(doc) do |xml|
			xml.holding {
				xml.record {
					xml.leader "^^^^^nx^^a22^^^^^1n^4500"
					xml.controlfield(:tag => '008') {xml.text controlfield_string}
					xml.datafield(:ind1 => '0', :tag => '852') {
						xml.subfield(:code => 'b') { xml.text params['code'][0] }
						xml.subfield(:code => 'c') { xml.text params['code'] }
						xml.subfield(:code => 'h') { xml.text "MS #{params['id']}" }
					}
				}
			}
		end

		builder.to_xml
	end

	def post_holdings(params)
		data = build_holdings(params)

		uri = URI("#{AppConfig[:alma_api_url]}/#{params['mms']}/holdings")
		uri.query = URI.encode_www_form({:apikey => AppConfig[:alma_apikey]})
		resp = post_request(uri, data, :use_ssl => true)

		doc = Nokogiri::XML(resp.body)
    if resp.is_a?(Net::HTTPSuccess)
			flash[:success] = "Holdings created. Holding ID: #{doc.at_css('holding_id').text}"
		else
			flash[:error] = "Error: #{doc.at_css('errorMessage').text} (#{doc.at_css('errorCode').text})"
		end

		redirect_to :action => :index
	end

end
