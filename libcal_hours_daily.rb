#!/usr/bin/ruby -w

#
# Show today's branch opening hours on current date, taken from Libcal Calendars
#
# Original Author: Ali Sadaqain <sadaqain@yorku.ca>
# https://github.com/asadaqain/branchhours
require 'json'
require 'date'
require 'time'
require 'yaml'
require 'optparse'
require 'open-uri'
require 'fileutils'
require_relative 'libcal_hours_functions.rb'

options = {}
options[:verbose] = false
options[:config] = 'libcal_hours.yml'

OptionParser.new do |opts|
  opts.banner = "Usage: libcal_hours [options]"
  opts.on("-c", "--config configFile", "specify configuration file") do |configFile|
    options[:config] = configFile
  end
  opts.on("-v", "--verbose",  "be verbose") { options[:verbose] = true }
end.parse!

# Hash to store opening hours, by date, then library
# schedule = Hash.new do |hash, key|
#   hash[key] = {}
# end

begin
  config = YAML.load_file(options[:config])
rescue Exception => e
  puts e
  exit 1
end

STDERR.puts "Creating Output Directories if needed ..."
begin
  FileUtils.mkdir_p config['dailyDir']
rescue Exception => e
  puts e
  exit 1
end

STDERR.puts "Getting LibCal Calendar ..."  if options[:verbose]

calendarUrl = config['calendarDailyURL']

begin
  # Had issues with Net::HTTP throwing exception of "end of file reached" on production.
  # Not sure why but open-uri worked better.

  #calendarJSON = Net::HTTP.get_response(URI.parse(calendarUrl)).body
  calendarJSON = URI.open(calendarUrl).read
rescue Exception => e
  STDERR.puts "Couldn't get #{library} calendar from Google"
  STDERR.puts "Can't connect to Google!? Aborting"
  STDERR.puts e
  exit 1
end

begin
  calendar  = JSON.parse(calendarJSON)
rescue Exception => e
  STDERR.puts "Can't parse the JSON for the #{library} calendar!? Aborting"
  STDERR.puts e
  exit 1
end

all_locations_file = "all_locations_daily_hours.html"

begin
  wholedayfile = File.new("#{config['dailyDir']}/all_locations_daily_hours.html", "w+")
  wholedayfile.chmod(0664)
rescue Exception => e
  STDERR.puts "Problem creating #{config['dailyDir']}/#{all_locations_file}. Aborting"
  STDERR.puts e
  exit 1
end

wholedayfile.write("<div class='row'>")

calendar['locations'].each_with_index do |location, i|
  location_name = location['name']
  location_url = location['url']
  location_name_sanitized = sanitize_filename(location_name)
  dayline = ''

  begin
    dayfile = File.new("#{config['dailyDir']}/#{location_name_sanitized}_daily_hours.html", "w+")
    dayfile.chmod(0664)
  rescue Exception => e
    STDERR.puts "Problem creating #{config['dailyDir']}/#{location_name_sanitized}_daily_hours.html. Aborting"
    STDERR.puts e
    exit 1
  end

  STDERR.puts location_name if options[:verbose]
  STDERR.puts "CARD LAYOUT" if options[:verbose]
  dayline = "
    <div class='card border-0'>\n
      <div class='card-body text-center p-2'>\n
        <p class='card-title fw-bold text-primary'><a href='#{location_url}'>#{location_name}</a></p>\n
        <p class='card-text small fw-bolder'>
          <i class='far fa-clock'></i> <span class='text-muted'>#{location['day']}\n
          </span>#{location['rendered']}
        </p>\n
      </div>\n
    </div>"
  STDERR.puts dayline if options[:verbose]

  dayfile.write(dayline)
  
  if (i+1)%3 == 0
    wholedayfile.write("</div><div class='row'>")
    wholedayfile.write(dayline)
  else  
    wholedayfile.write(dayline)
  end
  

end
wholedayfile.write('</div>')

begin
  dayfile = File.new("#{config['dailyDir']}/more_daily_hours.html", "w+")
  dayfile.chmod(0664)
rescue Exception => e
  STDERR.puts "Problem creating #{config['dailyDir']}/more_daily_hours.html. Aborting"
  STDERR.puts e
  exit 1
end

dayline = "
  <div class='card justify-content-center text-center border-0'>\n
    <div class='card-body text-center p-2'>\n
      <p class='card-title fw-bold text-dark'>See All Hours</p>\n
      <p class='card-text small fw-bolder'>
        <i class='far fa-clock'></i> <a href='https://www.library.yorku.ca//web/hours-and-locations'>Location and Hours</a>
      </p>\n

    </div>\n
  </div>"

STDERR.puts dayline if options[:verbose]
dayfile.write(dayline)
 