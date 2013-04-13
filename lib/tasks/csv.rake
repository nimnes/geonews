namespace :csv do
    require 'benchmark'
    require './lib/geonames/csv_to_db.rb'

    desc 'Import csv files with locations info to databases'
    task :import => :environment do
        puts '[CSV] IMPORT'.light_green
        time = Benchmark.realtime do
            import_all
        end
        puts "[CSV] IMPORT COMPLETED in #{'%.3f' % time} seconds".light_green
    end
end