require 'base64'
require 'openssl'
require 'net/http'
require 'nokogiri'
require 'time'
require 'uri'

class AmazonAffiliateService

  def initialize(endpoint, access_key_id, secret_key, associate_tag_id)
    # The region you are interested in
    @endpoint = endpoint

    # Access Key ID, as taken from the Your Account page
    @access_key_id = access_key_id

    # Secret Key corresponding to the above ID, as taken from the Your Account page
    @secret_key = secret_key

    # Your Associate Tag
    @associate_tag_id = associate_tag_id

    @request_uri = "/onca/xml"
  end

  def lookup_product(id)
    uri = URI.parse(get_request_url(id))

    response = Net::HTTP.get_response(uri)
    if response.code() != "200"
      print response.code()
      throw :halt, { :message => { :status => "unable to fetch product from remote: " + response.code() }, :status => :bad_request }
    end

    parse_xml(response.body())
  end

  private

  # from http://webservices.amazon.ca/scratchpad/index.html
  def get_request_url(id)
    params = {
      "Service" => "AWSECommerceService",
      "Operation" => "ItemLookup",
      "AWSAccessKeyId" => @access_key_id,
      "AssociateTag" => @associate_tag_id,
      "ItemId" => id[:value],
      "IdType" => id[:type],
      "ResponseGroup" => "Large"
    }

    # Set current timestamp if not set
    params["Timestamp"] = Time.now.gmtime.iso8601 if !params.key?("Timestamp")

    # Generate the canonical query
    canonical_query_string = params.sort.collect do |key, value|
      [URI.escape(key.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")), URI.escape(value.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))].join('=')
    end.join('&')

    # Generate the string to be signed
    string_to_sign = "GET\n#{@endpoint}\n#{@request_uri}\n#{canonical_query_string}"

    # Generate the signature required by the Product Advertising API
    signature = Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), @secret_key, string_to_sign)).strip()

    # Generate the signed URL
    request_url = "http://#{@endpoint}#{@request_uri}?#{canonical_query_string}&Signature=#{URI.escape(signature, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}"
  end

  def parse_xml(body)
    xml = Nokogiri::XML(body, nil, 'UTF-8')

    xml.remove_namespaces!

    product = {}

    # 1. Retrive the ASIN
    product[:asin] = xml.xpath('//Item/ASIN').text

    # 2. retrieve the product's rank
    product[:rank] = xml.xpath('//SalesRank').text

    error = xml.xpath('//Items/Request/Errors/Error')
    if !error.empty?
      throw :halt, { :message => { :status => "Product not found (wrong ID ?)" }, :status => :bad_request }
    end

    # 3. its dimensions, converted to a human readable format
    item_dimensions = xml.xpath('//ItemDimensions')
    if !item_dimensions.empty?
      dimensions = []
      [
        item_dimensions.at('Height'),
        item_dimensions.at('Length'),
        item_dimensions.at('Width'),
      ].each do |node|
        # XXX it is unclear what unit are possible
        case node.attribute("Units").text
        when "hundredths-inches"
          dimensions.push((node.text.to_i * 0.01).truncate(2).to_s + "\"")
        end
      end
      product[:dimensions] = dimensions.join('x')
    else
      product[:dimensions] = ""
    end

    # 4. and finally, its cotegory
    categories = []
    node = xml.xpath('//BrowseNodes/BrowseNode').first
    categories.push(node.at('Name').text)
    while node = node.at('Ancestors BrowseNode') do
      if !node.at_xpath('IsCategoryRoot').nil?
        next
      end
      categories.push(node.at('Name').text)
    end
    product[:category] = categories.join(" / ")

    product
  end
end

