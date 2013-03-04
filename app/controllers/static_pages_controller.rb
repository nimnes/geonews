# encoding: utf-8
require 'gchart'

class StaticPagesController < ApplicationController
    Feedzirra::Feed.add_common_feed_entry_element('location', :as => :location)

    def home
        @news = FeedEntry.where("location IS NOT NULL")
        render :action => "home", :layout => 'map'
    end

    def lemmatizer
        @entities = []
        if params[:input_text].blank?
            @input_text = ""
        else
            @entities = @@lemmatizer.define_location(params[:input_text])
            @input_text = params[:input_text]
        end
    end

    def help
    end

    def about
        no_category = FeedEntry.where("category is NULL").count
        global_news = FeedEntry.where("category = 'global'").count
        regional_news = FeedEntry.where("category = 'region'").count
        russian_news = FeedEntry.where("category = 'russia'").count
        towns_news = FeedEntry.where("category = 'population'").count

        labels = ["Неопределенные (%d / %.1f" % [no_category, (no_category / FeedEntry.all.count.to_f * 100)] + "%)",
                  "Мировые новости (%d / %.1f" % [global_news, (global_news / FeedEntry.all.count.to_f * 100)] + "%)",
                  "Российские новости (%d / %.1f" % [russian_news, (russian_news / FeedEntry.all.count.to_f * 100)] + "%)",
                  "Региональные новости (%d / %.1f" % [regional_news, (regional_news / FeedEntry.all.count.to_f * 100)] + "%)",
                  "По городам (%d / %.1f" % [towns_news, (towns_news / FeedEntry.all.count.to_f * 100)] + "%)"]
        data = [no_category, global_news, russian_news, regional_news, towns_news]

        @pie_chart = Gchart.pie(:data => data, :labels => labels, :size => '754x380')
    end

    def contact
    end
end
