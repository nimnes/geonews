# GeoNews

GeoNews is a project developed with Ruby on Rails 3 for mapping news from Russian mass media on map service.

## Description

Our project will grab news from RSS feeds, define location using lemmatization with database of geographical names 
and place a message on a map.

Thanks to AOT project (http://aot.ru) for dictionary of lemmas and
https://github.com/kanwei/algorithms for implementation of Trie structure on Ruby.

We use optimized version of Geonames database (only locations with population) from http://gis-lab.info/qa/geonames.html, 
own Countries with capitals DB and World cities DB  (http://download.geonames.org/export/dump/cities15000.zip).

## How to use?

At first you must create databases and import data from csv files

```ruby
rake db:create:all
rake db:migrate
rake csv:import
```

RSS feeds are stored in dicts/rssfeeds file, you can use

```ruby
rake feed:readfeeds
rake feed:update
```

for grabbing them and toponym recognition.

You can add your own rules for toponym recognition in dicts/csv/user_rules.csv file and import them by

```ruby
rake rules:import
```

All news are stored in FeedEntry database, which store general information from RSS (i.e. title, summary) and 
location coordinates. Location names are stored in tags field. 
