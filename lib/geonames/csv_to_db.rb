require 'csv'

def import_all
    import_geonames
    import_countries
    import_world_cities
    import_rules
end

def import_geonames
    CSV.foreach('./dicts/csv/geonames.csv', :headers => true, :col_sep => ';') do |row|
        Geonames.create!(row.to_hash)
    end
end

def import_countries
    CSV.foreach('./dicts/csv/countries.csv', :headers => true, :col_sep => ';') do |row|
        row_hash = row.to_hash

        Countries.where('geonameid = ?', row_hash[:geonameid]).first.update_attributes({:countrycode => row_hash.countrycode})

        #Countries.create!(row.to_hash)
    end
end

def import_world_cities
    CSV.foreach('./dicts/cities15000_parsed.csv', :headers => true, :col_sep => ';') do |row|
        row_hash = row.to_hash

        WorldCities.where('geonameid = ?', row[0]).first.update_attributes({:countrycode => row[4]})

    end
end

def import_rules
    CSV.foreach('./dicts/csv/user_rules.csv', :headers => true, :col_sep => ';') do |row|
        UserRules.create!(row.to_hash)
    end
end