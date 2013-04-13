require "csv"

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
        Countries.create!(row.to_hash)
    end
end

def import_world_cities
    CSV.foreach('./dicts/csv/world_cities.csv', :headers => true, :col_sep => ';') do |row|
        WorldCities.create!(row.to_hash)
    end
end

def import_rules
    CSV.foreach('./dicts/csv/user_rules.csv', :headers => true, :col_sep => ';') do |row|
        UserRules.create!(row.to_hash)
    end
end