require 'scraperwiki'
require 'mechanize'

case ENV['MORPH_PERIOD']
when 'thismonth'
  period = 'thismonth'
when 'lastmonth'
  period = 'lastmonth'
else
  period = 'thisweek'
end
puts "Getting '" + period + "' data, changable via MORPH_PERIOD environment";

url_base    = 'http://eservices.waverley.nsw.gov.au'
da_url      = url_base + '/Pages/XC.Track/SearchApplication.aspx?d=' + period + '&k=LodgementDate&t=A0,SP2A,TPO,B1,B1A,FPS'
comment_url = 'mailto:waver@waverley.nsw.gov.au?subject='

# Disable gzip otherwise server will return below error message
# in `response_content_encoding': unsupported content-encoding: gzip,gzip (Mechanize::Error)
agent = Mechanize.new
agent.request_headers = { "Accept-Encoding" => "" }

# Accept terms
page = agent.get(url_base + '/Common/Common/terms.aspx')
form = page.forms.first
page = form.click_button( form.button_with(:value => "I Agree") )

# Scrape DA page
page = agent.get(da_url)
results = page.search('div.result')

results.each do |result|
  council_reference = result.search('a.search')[0].inner_text.strip.split.join(" ")

  begin
    address = result.search('strong')[0].inner_text.strip.split.join(" ")
  rescue
    puts "Skipping " + council_reference + ". Failed to locate address"
    next
  end

  description = result.inner_text
  description = description.split( /\r?\n/ )
  description = description[3].strip.split.join(" ").split(' - ', 2)[1]

  info_url    = result.search('a.search')[0]['href']
  info_url    = info_url.sub!('../..', '')
  info_url    = url_base + info_url

  date_received = result.inner_text
  date_received = date_received.split(/Submitted:\r\n/)[1].split( /\r?\n/ )
  date_received = Date.parse(date_received[0].strip.to_s)

  record = {
    'council_reference' => council_reference,
    'address'           => address,
    'description'       => description,
    'info_url'          => info_url,
    'comment_url'       => comment_url + council_reference,
    'date_scraped'      => Date.today.to_s,
    'date_received'     => date_received.to_s
  }

  # Saving data
  if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
    puts "Saving record " + record['council_reference'] + ", " + record['address']
#     puts record
    ScraperWiki.save_sqlite(['council_reference'], record)
  else
    puts "Skipping already saved record " + record['council_reference']
  end
end
