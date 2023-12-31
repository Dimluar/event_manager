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

def get_complete_time(row)
  date = get_date(row)
  time = get_time(row)
  date.concat(time)
end

def get_time(row)
  converted_row = row.split
  converted_row[1].split(':').map(&:to_i)
end

def get_date(row)
  converted_row = row.split
  date = converted_row[0].split('/')
  clean_date(date).map(&:to_i)
end

def clean_date(date)
  date[0], date[2] = date[2], date[0]
  date[1], date[2] = date[2], date[1]
  date[0] = (date[0].to_i + 2000).to_s
  date
end

def get_most_frequent(array)
  counts = array.tally
  greatest_count = counts.reduce([0, 0]) do |result, values|
    values[1] > result[1] ? values : result
  end

  counts.filter_map do |values|
    values[0] if values[1] == greatest_count[1]
  end
end

WEEKDAYS = {
  0 => 'Sunday',
  1 => 'Monday',
  2 => 'Tuesday',
  3 => 'Wednesday',
  4 => 'Thursday',
  5 => 'Friday',
  6 => 'Saturday'
}.freeze

puts "\nEventManager initialized"
puts "\n"

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.html')
erb_template = ERB.new template_letter

hours = []
days = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  time = Time.new(*get_complete_time(row[:regdate]))
  hours.push(time.hour)

  date = Date.new(*get_date(row[:regdate]))
  days.push(date.wday)

  phone_number = clean_phone_number(row[:homephone])
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  puts "#{name}: #{phone_number}"
end

print "\nMore frequent hours: "
get_most_frequent(hours).each { |value| print "#{value}:00 " }
puts ''

print "\nMore frequent days of the week: "
get_most_frequent(days).each { |value| print "#{WEEKDAYS[value]} " }
puts ''
