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
    amazonAffiliateService = AmazonAffiliateService.new(
      "webservices.amazon.ca",
      ENV['AMAZON_ACCESS_KEY_ID'],
      ENV['AMAZON_SECRET_KEY'],
      ENV['AMAZON_ASSOCIATE_TAG_ID'],
    )
    ret = catch :halt do
      product = Product.new(amazonAffiliateService.lookup_product(id))
      product.save!

      response.set_header('Location', "/" + params[:controller] + "/" + product.id.to_s)

      { :message => product, :status => 201 }
    end

    render json: ret[:message], :status => ret[:status], :except => [:created_at, :updated_at]
  end

  def show
    params.permit(:id)

    id = params[:id]

    # parameter validation
    if !id.match(/\A[[:digit:]]+\z/)
      render json: { error: "invalid ID format: " + id }, :status => :bad_request and return
    end

    product = Product.find(id)

    render json: product, :status => 200, :except => [:created_at, :updated_at]
  end
end
