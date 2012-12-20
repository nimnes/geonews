class FeedEntry < ActiveRecord::Base
	attr_accessible :guid, :name, :published_at, :summary, :url, :location

	def self.update_from_feed(feed_url)
		feed = Feedzirra::Feed.fetch_and_parse(feed_url)
		add_entries(feed.entries)
	end

	private
	def self.add_entries(entries)
		entries.each do |entry|

			unless exists? :guid => entry.id
				create!(
					:name         => entry.title,
					:summary      => entry.summary,
					:url          => entry.url,
					:published_at => entry.published,
					:guid         => entry.id,
                    :location     => ""
					)
            end

            if entry.location.blank?
                geo_names = ""

                # extract geo names from title
                @@lemmatizer.define_location(entry.title).each do |location|
                    geo_names += location[1] + ", "
                end

                # extract geo names from body
                @@lemmatizer.define_location(entry.summary).each do |location|
                    geo_names += location[1] + ", "
                end

                unless geo_names.blank?
                    geo_names = geo_names[0...-2]
                end

                self.update_location(entry, geo_names)
            end
		end
    end

    def self.update_location(entry, location)
        entry.update_attributes({:location => location})
    end

	def self.update_from_feed_continuously(feed_url, delay_interval = 15.minutes)
		feed = Feedzirra::Feed.fetch_and_parse(feed_url)
		add_entries(feed.entries)
		loop do
			sleep delay_interval.to_i
			feed = Feedzirra::Feed.update(feed)
			add_entries(feed.new_entries) if feed.updated?
		end
	end
end
