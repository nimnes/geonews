require "./lib/lemmatizer/lemmatizer"

class StaticPagesController < ApplicationController
  @@lemmatizer = Lemmatizer.new

  def home
    render :action => "home", :layout => 'map'
  end

  def news
 	  @news = FeedEntry.paginate(page: params[:page], per_page: 50)
  end

  def lemmatizer
    if !params[:input_text].blank?
      @normalized_text = @@lemmatizer.define_location(params[:input_text])
      @input_text = params[:input_text]
    else
      @input_text = ""
      @normalized_text = []
    end
  end

  def help
  end

  def about
  end

  def contact
  end
end
