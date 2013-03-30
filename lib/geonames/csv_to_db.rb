require "csv"

def import_csv()
    CSV.foreach('./dicts/user_rules.csv', :headers => true, :col_sep => ';') do |row|
        UserRules.create!(row.to_hash)
    end
end