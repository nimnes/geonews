namespace :rules do
    require 'benchmark'
    require './lib/geonames/csv_to_db.rb'

    desc 'Import csv files with locations info to databases'
    task :import => :environment do
        puts '[RULES] IMPORT'.light_green
        time = Benchmark.realtime do
            UserRules.delete_all
            import_rules
        end
        puts "[RULES] IMPORT COMPLETED in #{'%.3f' % time} seconds".light_green
    end
end