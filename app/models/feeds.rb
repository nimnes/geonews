class Feeds < ActiveRecord::Base
  attr_accessible :etag, :feed_url, :last_modified, :title, :url, :category
end
