require "csv"

def import_csv()
    CSV.foreach('./dicts/cities15000_parsed.csv', :headers => true, :col_sep => ';') do |row|
        WorldCities.create!(row.to_hash)
    end
end