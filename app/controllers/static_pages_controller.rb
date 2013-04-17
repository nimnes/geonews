# encoding: utf-8
require 'gchart'

class StaticPagesController < ApplicationController
    Feedzirra::Feed.add_common_feed_entry_element('location', :as => :location)

    ALL_TIME = '0'
    ONE_DAY = '1'
    THREE_DAYS = '2'
    WEEK = '3'
    MONTH = '4'

    def home
        news_period = ALL_TIME
        news_category = ALL

        if params[:period].present?
            news_period = params[:period]
        end

        if params[:category].present?
            news_category = params[:category].to_i
        end

        if news_category == ALL
            case params[:period]
                when ONE_DAY
                    @news = FeedEntry.where('location is NOT NULL AND published_at >= ?', 1.days.ago)
                when THREE_DAYS
                    @news = FeedEntry.where('location is NOT NULL AND published_at >= ?', 3.days.ago)
                when WEEK
                    @news = FeedEntry.where('location is NOT NULL AND published_at >= ?', 1.weeks.ago)
                when MONTH
                    @news = FeedEntry.where('location is NOT NULL AND published_at >= ?', 1.months.ago)
                else
                    @news = FeedEntry.where('location IS NOT NULL')
            end
        else
            case params[:period]
                when ONE_DAY
                    @news = FeedEntry.where('location is NOT NULL AND published_at >= ? AND feedcategory = ?', 1.days.ago, news_category)
                when THREE_DAYS
                    @news = FeedEntry.where('location is NOT NULL AND published_at >= ? AND feedcategory = ?', 3.days.ago, news_category)
                when WEEK
                    @news = FeedEntry.where('location is NOT NULL AND published_at >= ? AND feedcategory = ?', 1.weeks.ago, news_category)
                when MONTH
                    @news = FeedEntry.where('location is NOT NULL AND published_at >= ? AND feedcategory = ?', 1.months.ago, news_category)
                else
                    @news = FeedEntry.where('location IS NOT NULL AND feedcategory = ?', news_category)
            end
        end

        render :action => 'home', :layout => 'map'
    end

    def lemmatizer
        @entities = []
        if params[:input_text].blank?
            @input_text = ''
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
