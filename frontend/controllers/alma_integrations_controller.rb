class AlmaIntegrationsController < ApplicationController

	set_access_control "view_repository" => [:index, :search, :add_bibs, :add_holdings]

	def index
	end

	def search
		results = do_search(params['resource']['ref'])
		render_aspace_partial :partial => "alma_integrations/results", :locals => {:results => results}
	end

	def add_bibs
		post_bibs(params)
		redirect_to request.referer
	end

	def add_holdings
		post_holdings(params)
		redirect_to action: "index"
	end

	private

	def integrator
		AlmaIntegrator.new(AppConfig[:alma_api_url], AppConfig[:alma_apikey])
	end

	def do_search(ref)
		json = JSONModel::HTTP::get_json(ref)
		results = {
			'title' => json['title'],
			'ref' => ref,
			'id' => json['id_0']
		}

		if (json['user_defined'].nil? || json['user_defined']['string_2'].nil?)
			return results
		else
			results['mms'] = json['user_defined']['string_2']
		end

		results['bib_found'] = integrator.bib_search(results['mms'])
		results['holdings'] = integrator.holding_search(results['mms'])
		results
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
		if response.is_a?(Net::HTTPSuccess)
			flash[:success] += " and MMS ID added to Resource"
		else
			flash[:error] = "Error: Couldn't add MMS ID to Resource!"
		end
	end

	def post_bibs(params)
		marc_url = URI.join(AppConfig[:backend_url], params['ref'].gsub(/(\d+?)$/, 'marc21/\1.xml'))
		data = RecordBuilder.new.build_bib(marc_url, params['mms'])
		response = integrator.post_bib(params['mms'], data)

		if response.is_a?(Net::HTTPSuccess)
			if params['mms'].nil?
				doc = Nokogiri::XML(response.body)
				mms = doc.at_css('mms_id').text
				flash[:success] = "BIB record #{mms} created"
				update_resource(params['ref'], mms)
			else
				flash[:success] = "BIB record #{params['mms']} updated"
			end
		else
			flash[:error] = "An error occurred: #{response.body}"
		end
	end

	def post_holdings(params)
		data = RecordBuilder.new.build_holding(params['code'], params['id'])
		response = integrator.post_holding(params['mms'], data)

		doc = Nokogiri::XML(response.body)
    if response.is_a?(Net::HTTPSuccess)
			flash[:success] = "Holdings created. Holding ID: #{doc.at_css('holding_id').text}"
		else
			flash[:error] = "An error occurred: #{response.body}"
		end
	end

end
