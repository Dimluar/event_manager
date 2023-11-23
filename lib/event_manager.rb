# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def valid_legislators_by_zipcode(zip, info)
  info.representative_info_by_address(
    address: zip,
    levels: 'country',
    roles: %w[legislatorUpperBody legislatorLowerBody]
  ).officials
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    valid_legislators_by_zipcode(zip, civic_info)
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thaks_#{id}.html"

  File.open(filename, 'w') { |file| file.puts form_letter }
end

def clean_phone_number(phone_number)
  phone_number = phone_number.tr('()', '').tr(' ', '').tr('-', '').tr('.', '')

  digits = phone_number.length
  return 'Invalid phone number' if digits < 10 || (digits > 10 && phone_number[0] != '1')

  if digits > 10
    phone_number[1...digits]
  else
    phone_number
  end
end

puts "\nEventManager initialized"

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.html')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone_number = clean_phone_number(row[:homephone])
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  puts "#{name}: #{phone_number}"
end
