require 'base64'
require 'net/http'
require 'openssl'
require 'nokogiri'
require 'time'
require 'uri'

class Amazon

  # Access Key ID, as taken from the Your Account page
  ACCESS_KEY_ID = "AKIAJKLXRSGXMDUCBPQQ"

  # Secret Key corresponding to the above ID, as taken from the Your Account page
  SECRET_KEY = ENV['AMAZON_SECRET_KEY']

  # Your Associate Tag
  ASSOCIATE_TAG_ID = "aerilon-09-20"

  # The region you are interested in
  ENDPOINT = "webservices.amazon.ca"

  REQUEST_URI = "/onca/xml"

  # from http://webservices.amazon.ca/scratchpad/index.html
  def self.get_request_url(id)
    params = {
      "Service" => "AWSECommerceService",
      "Operation" => "ItemLookup",
      "AWSAccessKeyId" => ACCESS_KEY_ID,
      "AssociateTag" => ASSOCIATE_TAG_ID,
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
    string_to_sign = "GET\n#{ENDPOINT}\n#{REQUEST_URI}\n#{canonical_query_string}"

    # Generate the signature required by the Product Advertising API
    signature = Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), SECRET_KEY, string_to_sign)).strip()

    # Generate the signed URL
    request_url = "http://#{ENDPOINT}#{REQUEST_URI}?#{canonical_query_string}&Signature=#{URI.escape(signature, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}"
  end

  def self.parse_xml(body)
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
    # TODO `ItemDimensions' might not be available for every product
    dimensions = []
    [
      xml.xpath('//ItemDimensions/Height'),
      xml.xpath('//ItemDimensions/Length'),
      xml.xpath('//ItemDimensions/Width'),
    ].each do |node|
      # XXX it is unclear what unit are possible
      case node.attribute("Units").text
      when "hundredths-inches"
        dimensions.push((node.text.to_i * 0.01).to_s + "\"")
      end
    end
    product[:dimensions] = dimensions.join('x')

    # 4. and finally, its cotegory
    categories = []
    node = xml.xpath('//BrowseNodes/BrowseNode').first
    categories.push(node.at('Name').text)
    while node = node.at('Ancestors BrowseNode') do
      categories.push(node.at('Name').text)
    end
    product[:category] = categories.join(" / ")

    product
  end

  def self.lookup(id)
    uri = URI.parse(self.get_request_url(id))

    response = Net::HTTP.get_response(uri)
    if response.code() != "200"
      print response.code()
      throw :halt, { :message => { :status => "unable to fetch product from remote: " + response.code() }, :status => :bad_request }
    end

    self.parse_xml(response.body())
  end
end

class V1::ProductController < ApplicationController
  def create
    id = params.require(:product).require(:id).permit(:type, :value)

    # parameter validation
    case id[:type]
    when "ASIN"
      if !id[:value].match(/\A[A-Z0-9]{10}\z/)
        render json: { error: "invalid ASIN: " + id[:value] }, :status => :bad_request and return
      end
    else
      render json: { error: "unknown parameter type: " + id[:type] }, :status => :bad_request and return
    end

    # Check for duplicates
    product = Product.find_by(asin: id[:value])
    if id[:type] == "ASIN" and !product.nil?
      response.set_header('Location', "/" + params[:controller] + "/" + product.id.to_s)

      render json: { error: "product already exist" }, :status => :see_other and return
    end

    # Let's go !
    ret = catch :halt do
      Product.create(Amazon::lookup(id))
      { :message => { :status => "Ok" }, :status => 200 }
    end

    render json: ret[:message], :status => ret[:status]
  end

  def show
    params.permit(:id)

    id = params[:id]

    # parameter validation
    if !id.match(/\A[[:digit:]]+\z/)
      render json: { error: "invalid ID format: " + id }, :status => :bad_request and return
    end

    product = Product.find(id)

    render json: product, :status => 200
  end

  private def fetch_product(id)
  end
end
