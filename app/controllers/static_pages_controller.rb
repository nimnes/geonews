class StaticPagesController < ApplicationController
  def home
  end

  def news
 	@news = FeedEntry.paginate(page: params[:page], per_page: 50)
  end

  def help
  end

  def about
  end

  def contact
  end
end
