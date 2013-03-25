require "csv"

def import_csv()
    CSV.foreach('./dicts/areas.csv', :headers => true, :col_sep => ';') do |row|
        Geonames.create!(row.to_hash)
    end
end