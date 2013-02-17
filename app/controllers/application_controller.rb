require "./lib/lemmatizer/lemmatizer"

class ApplicationController < ActionController::Base
    protect_from_forgery

    @@lemmatizer = Lemmatizer.new
    FeedEntry.set_lemmatizer(@@lemmatizer)
end
