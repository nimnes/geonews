# GeoNews

GeoNews is a project developed with Ruby on Rails 3 for mapping news from Russian mass media on map service.

## Description

Our project will grab news from RSS feeds, define location using lemmatization with database of geographical names 
and place a message on a map.

Thanks to AOT project (http://aot.ru) for dictionary of lemmas and
https://github.com/kanwei/algorithms for implementation of Trie structure on Ruby.

## How to use

At first you must create databases and import data from csv files

```ruby
rake db:migrate
rake csv:import
```

RSS feeds are stored in dicts/rssfeeds file, you can use

```ruby
rake feed:readfeeds
rake feed:update
```

for grabbing and toponym recognition for them
