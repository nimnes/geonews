class StaticPagesController < ApplicationController
    Feedzirra::Feed.add_common_feed_entry_element('location', :as => :location)

    FeedEntry.set_lemmatizer(@@lemmatizer)

    unless FeedEntry.any?
        FeedEntry.update_from_feed("vesti.ru/vesti.rss")
    end

    def home
        @news = FeedEntry.where("location <> ''")
        render :action => "home", :layout => 'map'
    end

    def news
        @news = FeedEntry.where("location <> ''").paginate(page: params[:page], per_page: 50)
    end

    def lemmatizer
        if params[:input_text].blank?
            @input_text = ""
            @locations = []
        else
            @locations = @@lemmatizer.define_location_full(params[:input_text])
            @input_text = params[:input_text]
        end
    end

    def help
    end

    def about
    end

    def contact
    end
end
