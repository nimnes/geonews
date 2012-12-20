# encoding: utf-8
require "csv"

writer = CSV.open('../../dicts/geonames_parsed.csv', 'wb', options={:col_sep => ';'})

CSV.foreach('../../dicts/geonames.csv', options={:col_sep => ';'}) do |row|
    ru_names = ""
    unless row[3].nil?
        alt_names = row[3].split(',')

        alt_names.each do |name|
            if name.match(/([а-яА-Я]\s*)+/)
                ru_names << name << ","
            end
        end

        unless ru_names == ""
            ru_names = ru_names[0...-1]
        end
    end

    if ru_names != ""
        writer << [row[0],ru_names, row[4], row[5], row[6], row[14]]
    end
end
