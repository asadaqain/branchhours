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

#all_locations_file = "all_locations_daily_hours.html"

begin
  wholedayfile = File.new("#{config['dailyDir']}/all_locations_daily_hours_2024.html", "w+")
  wholedayfile.chmod(0664)
rescue Exception => e
  STDERR.puts "Problem creating #{config['dailyDir']}/#{all_locations_file}. Aborting"
  STDERR.puts e
  exit 1
end

# Short Names and Order of Listing
# Step 1: Collect selected lid records into an array and sort them
selected_lids = [6946, 6947, 6934, 6939, 6952, 6926, 8109, 7571, 8111]
short_names = {
  6926 => "Steacie Science and Engineering Library",
  6952 => "Frost Library/Bibliothèque Frost",
  6934 => "Scott Library",
  6946 => "Libraries Chat",
  6947 => "Clavardage des bibliothèques",
  6939 => "Bronfman Business Library",
  8109 => "Markham Campus Library",
  7571 => "Making and Media Creation Lab (Scott)",
  8111 => "Making and Media Creation Lab (Markham)"
}
# Filter and sort the locations by selected_lids index
sorted_locations = calendar['locations'].select do |location|
  selected_lids.include?(location['lid'])
end.sort_by { |location| selected_lids.index(location['lid']) }

##########################
#### WHOLEFILE SIDEBAR ###
##########################

# Step 2: Build row strings for the sorted locations
selected_rows = sorted_locations.each_with_index.map do |location, index|
  location_name = location['name']
  location_url = location['url']
  short_name = short_names[location['lid']] || location_name
  row_class = index.even? ? 'bg-yul-light' : 'bg-white' # Alternating row colors

  "<div class='row align-items-center p-2 border-bottom #{row_class}'>
    <!-- Location Column -->
    <div class='col-12 col-md'>
      <a href='#{location_url}' class='text-decoration-none'>#{short_name}</a>
    </div>
    <!-- Time Column -->
    <div class='col-12 col-md-auto text-md-end'>
      <i class='far fa-clock me-2'></i> #{location['rendered']}
    </div>
  </div>"
end
# Step 3: Add the custom link to the selected_daylines
custom_link_row = "<div class='row align-items-center p-2 border-bottom'>
    <!-- Location Column -->
    <div class='col-12 col-md text-center'>
      <a href='/web/hours-and-locations' class='text-decoration-none'>See all hours</a>
    </div>
  </div>"
selected_rows << custom_link_row

# Step 4: Write to file.
wholedayfile.write("<div class='container-fluid bg-white'>")
selected_rows.each do |row|
  wholedayfile.write(row)
end
wholedayfile.write('</div>') # Close the last row
wholedayfile.close
