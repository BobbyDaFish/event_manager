# frozen-string-literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('../output') unless Dir.exist?('../output')

  filename = "../output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_phone_numbers(phone)
  phone_chars = phone.tr('()-. ', '').split(//)

  if phone_chars.length == 11 && phone_chars[0] == '1'
    phone_chars.shift
  elsif phone_chars.length > 11 || phone_chars.length < 10
    phone_chars = ['invalid number']
  end
  phone_chars.join
end

def save_registration_times(registrations, time)
  File.write("../#{time}_trends.csv", "#{time}, registered") unless File.exist?("../#{time}_trends.csv")
  registration_trends = CSV.new(File.open("../#{time}_trends.csv"))

  CSV.open("../#{time}_trends.csv", 'w') do |csv|
    csv << ["#{time}", 'registered']
    registrations.each { |k, v| csv << [k, v] }
  end
end

puts 'Event Manager Initialized.'

contents = CSV.open(
  '../event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('../form_letter.erb')
erb_template = ERB.new template_letter
register_hours = Hash.new(0)
register_days = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  phone_numbers = clean_phone_numbers(row[:homephone])

  time_registered = Time.strptime(row[:regdate], '%D %H:%M')

  register_hours[time_registered.hour] += 1

  register_days[time_registered.strftime('%A')] += 1

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

save_registration_times(register_hours, 'Hour')
save_registration_times(register_days, 'Weekday')
