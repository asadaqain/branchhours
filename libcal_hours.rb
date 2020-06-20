#!/usr/bin/ruby -w

#
# Show today's branch opening hours, taken from Libcal Calendars
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
schedule = Hash.new do |hash, key|
  hash[key] = {}
end

begin
  config = YAML.load_file(options[:config])
rescue Exception => e
  puts e
  exit 1
end

STDERR.puts "Creating Output Directories if needed ..."
begin
  FileUtils.mkdir_p config['outputDir']
  FileUtils.mkdir_p config['weeklyDir']
rescue Exception => e
  puts e
  exit 1
end

STDERR.puts "Getting LibCal Calendar ..."  if options[:verbose]

calendarUrl = config['calendarURL']

begin
  # Had issues with Net::HTTP throwing exception of "end of file reached" on production.
  # Not sure why but open-uri worked better.

  #calendarJSON = Net::HTTP.get_response(URI.parse(calendarUrl)).body
  calendarJSON = open(calendarUrl).read
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

# puts calendar.to_json
hidden = ''

calendar['locations'].each do |location|
  location_name = location['name']
  location_id = location['lid']
  location_url = location['url']
  weekhtml = ''

  begin
    weekfile = File.new("#{config['weeklyDir']}/#{location_name}_hours.html", "w+")
    weekfile.chmod(0664)
  rescue Exception => e
    STDERR.puts "Problem creating #{config['weeklyDir']}/#{location_name}_hours.html. Aborting"
    STDERR.puts e
    exit 1
  end

  STDERR.puts location_name if options[:verbose]

  weekhtml << "<h3>#{location_name}</h3>\n"

  location['weeks'].each_with_index do |week, index|
    # puts "************** WEEK ***************"
    # puts week.inspect

    weekhtml << "<ul id='week_#{index.to_s}' "
    if index == 0
      weekhtml << "class='' >\n"
    else
      weekhtml << "class='hidden' >\n"
    end

    week.each do |day|
      # puts "************** DAY ***************"
      # puts day.inspect
      hours = day[1]['rendered']
      if hours.empty?
        dayweek_date = Date.parse(day[1]['date']).strftime('%b %d')
        weekline = "<li><span class=\"date\">#{dayweek_date}</span><span class=\"day\">#{day[0]}</span><span class=\"hours\">**notset**</span></li>\n"
        STDERR.puts "WEEKLINE(blank): " + week_date + " " + day[0] + " NOTSET" if options[:verbose]
      else
        dayweek_date = Date.parse(day[1]['date']).strftime('%b %d')
        weekline = "<li><span class=\"date\">#{dayweek_date}</span><span class=\"day\">#{day[0]}</span><span class=\"hours\">#{day[1]['rendered']}</span></li>\n"
        STDERR.puts "WEEKLINE: " + week_date + " " + day[0] + " " + day[1]['rendered'] if options[:verbose]
      end
      weekhtml << weekline
      weekline = ''
    end ## DAY LOOP

    weekhtml << "</ul>\n"

    STDERR.puts '=============================' if options[:verbose]

  end ## WEEK LOOP

  STDERR.puts weekhtml if options[:verbose]
  weekfile.write(weekhtml)

end ## LOCATION LOOP
