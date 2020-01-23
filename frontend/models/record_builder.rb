require 'nokogiri'

class RecordBuilder

  def build_bib(record, mms)
    marc = Nokogiri::XML(record)

    # Nokogiri won't put 'standalone' in the header so you have to do it yourself
    header = Nokogiri::XML('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')

    doc = Nokogiri::XML::Builder.with(header){ |xml| xml.bib }.to_xml

    data = Nokogiri::XML(doc)
    if mms
    	mms_id = Nokogiri::XML::Node.new('mms_id', data)
    	mms_id.content = mms
    	data.root.add_child(mms_id)
    end
    data.root.add_child(marc.at_css('record'))

    data.to_xml
  end

  def build_holding(code, id)
    controlfield_string = Time.now.strftime("%y%m%d")
    controlfield_string += "2u^^^^8^^^4001uueng0000000"
    # populate 852$b from alma_holdings config
    building = AppConfig[:alma_holdings].select{|a| a[1] == code}.first[0]

    # Nokogiri won't put 'standalone' in the header so you have to do it yourself
    doc = Nokogiri::XML('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')

    builder = Nokogiri::XML::Builder.with(doc) do |xml|
    	xml.holding {
    		xml.record {
    			xml.leader "^^^^^nx^^a22^^^^^1n^4500"
    			xml.controlfield(:tag => '008') { xml.text controlfield_string }
    			xml.datafield(:ind1 => '0', :tag => '852') {
    				xml.subfield(:code => 'b') { xml.text building }
    				xml.subfield(:code => 'c') { xml.text code }
    				xml.subfield(:code => 'h') { xml.text "MS #{id}" }
    			}
    		}
    	}
    end

    builder.to_xml
  end

end
