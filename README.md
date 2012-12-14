# GeoNews

GeoNews is a project developed with Ruby on Rails 3 for mapping news from Russian mass media on map service.

## Description

Our project will grab news from RSS feeds, define location using lemmatization with database of geographical names 
and place a message on a map.

Thanks to AOT project (http://aot.ru) for dictionary of lemmas and
https://github.com/kanwei/algorithms for implementation of Trie structure on Ruby.

## Dependencies

GeoNews uses the following gems:
```ruby
gem 'bootstrap-sass'
gem 'bootstrap-will_paginate'
gem 'feedzirra'
gem 'will_paginate'
gem 'algorithms'
gem 'unicode_utils'
```