require "logstash/filters/base"
require "logstash/namespace"
require "restclient"
require "nokogiri"

# Reads events from Abiquo API.
class LogStash::Inputs::Abiquoevents < LogStash::Inputs::Base

  config_name "abiquoevents"
  plugin_status "experimental"

  # Replace the message with this value.
  config :message, :validate => :string

  # Your abiquo user with api rights
  config :user, :validate => :string, :required => true
  # Your abiquo password
  config :password, :validate => :string, :required => true
  # Your server
  config :server, :validate => :string, :required => true 

  # Interval between calls
  config :interval, :validate => :number, :required => true

  # 
  # Set true if you want to collect all available data
  # 
  config :historic, :validate => :boolean, :default => false
  # Set this to true to enable debugging on an input.
  config :debug, :validate => :boolean, :default => false
  
  
  

  public
  def initialize(params)
    super
    @format = "plain"
    url = "http://#{@server}/api/events?limit=1"
    p "Retrieving #{url} #{@user} #{@password}"
    xml = RestClient::Request.new(:method => :get, :url => url, :user => @user, :password => @password).execute
    output = []
    if xml.code == 200
      d = Nokogiri::XML.parse(xml)
      # Retrieves only one element to get latest timestamp
      @timestamp = d.at('//event/timestamp').to_str
    end # if
    @timestamp="1900-01-01T00:00:00+02:00" if @historic
    p "timesamp set to #{@timestamp}"
  end #def

  private 
  def get_number_events()
    url = "http://#{@server}/api/events?datefrom=#{Time.parse(@timestamp).to_i}"
    p "Getting number of generated events from #{url}"
    xml = RestClient::Request.new(:method => :get, :url => url, :user => @user, :password => @password).execute
    return Nokogiri::XML.parse(xml).at('totalSize').to_str if xml.code == 200
    return nil
  end # def get_event_numbers

  private
  def get_events()
    output = []

    url = "http://#{@server}/api/events?datefrom=#{Time.parse(@timestamp).to_i}&limit=#{get_number_events}"
    p "Getting events since #{@timestamp} from #{url}"

    xml = RestClient::Request.new(:method => :get, :url => url, :user => @user, :password => @password).execute

    if xml.code == 200
      d = Nokogiri::XML.parse(xml)
      d.xpath('//event').each { |event|
     	p "Evento from xml: #{event.at('id').to_str} timestamp #{event.at('timestamp').to_str}"
	if Time.parse(event.at('timestamp').to_str).to_i > Time.parse(@timestamp).to_i
	  p "Event Timestamp #{event.at('timestamp').to_str}"
	  p "Event tiemstamp Parsed #{Time.parse(event.at('timestamp').to_str).to_i}"
	  output << event
	  p "Event publised #{event.at('id').to_str} timestamp #{event.at('timestamp').to_str}"
	end # if
      }

      @timestamp = d.xpath('//event/timestamp')[0].to_str
      p "Finished get events / Set timestamp #{@timestamp}"
      return output
    end # if
  end # def get_events
  
  public
  def register
    # nothing to do
    @logger.info("Registering Abiquo-events input")
  end # def register
    
  public
  def run(queue)
    loop do
      start = Time.now

      
      get_events.each { |event|
        	
	p "Event class #{event.class}"
	p "Event Inspect #{event.inspect}"
#	p "Event to_srt #{event.to_str}"
	stacktrace = event.at('stacktrace').to_str
	p "Event at #{stacktrace}"

        e = to_event(stacktrace,@server)

        e.fields.merge!(
	  "id" => event.at('id').to_str,
 	  'actionPerformed' => event.at('actionPerformed').to_str,
          'component' => event.at('component').to_str,
	  'enterprise' => event.at('enterprise').to_str,
	  'idEnterprise' => event.at('idEnterprise').to_str.to_i,
	  'idUser' => event.at('idUser').to_str.to_i,
#	  'idVirtualApp' => event.at('idVirtualApp').to_str,
#	  'idVirtaulDatacenter' => event.at('idVirtualDatacenter').to_str,
	  'performedBy' => event.at('performedBy').to_str,
	  'severity' => event.at('severity').to_str,
	  'timestamp' => event.at('timestamp').to_str,
	  'user' => event.at('user').to_str,
#	  'virtualApp' => event.at('virtualApp').to_str,
#	  'virtualDatacenter' => event.at('virtualDatacenter').to_str
        )
	p e
	p 'to_event generated'
	queue << e
      } # get events

      duration = Time.now - start
      @logger.info("Run complete", :duration => duration) if @debug

      sleeptime = [0, @interval - duration].max
      if sleeptime == 0
        @logger.warn("Execution ran longer than the interval. Skipping sleep.",
                     :duration => duration,
                     :interval => @interval)
      else
        sleep(sleeptime)
      end #if 
	
    end # loop
  end # def run
end # class LogStash::Filters::Abiquo-events
