class StaticPagesController < ApplicationController
    Feedzirra::Feed.add_common_feed_entry_element('location', :as => :location)

    def home
        @news = FeedEntry.where("location <> ''")
        render :action => "home", :layout => 'map'
    end

    def lemmatizer
        @locations = []
        if params[:input_text].blank?
            @input_text = ""
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
