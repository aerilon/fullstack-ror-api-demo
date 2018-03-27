class V1::ProductsController < ApplicationController
  def show
    render json: Product.all, :except => [:created_at, :updated_at]
  end
end
