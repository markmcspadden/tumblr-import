require 'rubygems'
require 'active_record'
require 'net/http'

# WARN ABOUT INTEGRATIONS
unless ARGV.to_s[/--skip-warning/]
  puts "WARNING: If you use any Tumblr integrations (like twitter or facebook), turn those off before importing these feeds."
  puts "Giving 10 seconds to abort if desired"
  10.times{ |i| puts "#{10-i}"; sleep 1 }
end

# Push mysql file into mysql
if ARGV.to_s[/--upload-sql/]
  puts "Load mysql from mephisto"
  `mysql -u root < #{File.expand_path(File.dirname(__FILE__) + "/mephisto_archives.sql")}`
end

# Create AR::Base classes for the articles
ActiveRecord::Base.establish_connection(:adapter => "mysql", :host => "localhost", :database => "mephisto_archives", :user => "root")
class Content < ActiveRecord::Base; end
class Article < Content; end
class Comment < Content; end

# Get creds from command line arguments
TUMBLR_USER = ARGV.join(" ")[/TUMBLR_USER=(\S*)/].split("=").last #'your@email.com'
TUMBLR_PASS = ARGV.join(" ")[/TUMBLR_PASS=(\S*)/].split("=").last #'yourpassword'
if TUMBLR_USER.blank? || TUMBLR_PASS.blank?
  abort "TUMBLR_USER and/or TUMBLR_PASS not included"
end

# Use our classes and the tumblr api to push things to tumblr
puts "Attempting upload to Tumblr for: puts #{TUMBLR_USER}:#{TUMBLR_PASS}"

url = URI.parse('http://www.tumblr.com/api/write')

counter = 0
Article.all.each do |article|
  # Only grab published articles
  if article.state == "ContentState::Published"
    puts "Publishing #{article.title}"
    counter +=1

    puts "-----------------------"

    attributes = {
      'email' => TUMBLR_USER,
      'password' => TUMBLR_PASS,
      'type' => 'regular',
      'format' => 'markdown', # article.text_filter.markup, TEXTILE DOESN'T SEEM TO WORK
      'title' => article.title,
      'date' => article.published_at,
      'slug' => article.permalink,
      'body' => article.body,
      'tags' => article.keywords,
      'state' => 'published'  
    }
    
    res = Net::HTTP.post_form(url, attributes)
        
    puts res.body # This will return the id of the newly created article...hopefully
    sleep(1)
    if counter % 5 == 0
      # sleep for a longer amount of time every 5 items 
      sleep(30)
    end
  end
end