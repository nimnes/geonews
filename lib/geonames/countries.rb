require "csv"

def import_csv()
    CSV.foreach('./dicts/countries_all.csv', :headers => true, :col_sep => ';') do |row|
        Countries.create!(row.to_hash)
    end
end