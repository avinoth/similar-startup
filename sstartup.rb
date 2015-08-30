require 'httparty'

class Object
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

  def present?
    !blank?
  end
end

class Angel
  def initialize
    @angel_url = "https://api.angel.co/1"
    @angel_token = ENV['ANGEL_TOKEN']
  end

  def get_similar startup_name
    startup = find_startup startup_name
    unless startup.present?
      puts "Couldn't find the #{startup_name} from search."
      return false
    end

    puts "Found #{startup_name} in AngelList. It's name is - '#{startup['name']}'' Getting more info."

    startup = fetch_info startup["id"].to_s
    if startup["hidden"]
      puts "#{startup_name} have it's details hidden in AngelList. Couldn't proceed."
      return false
    end

    if startup["markets"].present?
      puts "Got more Info about #{startup_name}. Fetching Market Tags and their children count."
      tags_hash = fetch_tag_children startup["markets"]
    elsif startup["locations"].present?
      puts "#{startup_name} has no Market tags. Fetching it's Location tags."
      tags_hash = fetch_tag_children startup["locations"]
    else
      puts "#{startup_name} has neither Location Tags nor Market tags. Couldn't proceed."
      return false
    end

    puts "Got Tag Information. Getting startups from the tag."
    similar = {}
    tags_hash.each do |k, v|
      similar = find_startup_by_tag k
      if similar.present?
        puts "Found a similar startup!"
        break
      end
    end
    return similar
  end

  def find_startup startup_name
    params_hash = {
          query: startup_name,
          type: "Startup",
          access_token: @angel_token
        }
    search_url = @angel_url + '/search?' + URI.encode_www_form(params_hash)
    results = get_data search_url

    return results.first
  end

  def fetch_info id
    fetch_url = @angel_url + '/startups/' + id + '?access_token=' + @angel_token
    return get_data fetch_url
  end

  def fetch_tag_children tags
    children = {}
    tags.each do |tag|
      tag_url = @angel_url + '/tags/' + tag["id"].to_s + '?access_token=' + @angel_token
      result = get_data tag_url

      children[tag["id"]] = result["total"]
    end
    Hash[children.sort]
  end

  def find_startup_by_tag tag
    params = {
      access_token: @angel_token,
      page: rand(1..1)
    }
    fetch_url = @angel_url + '/tags/' + tag.to_s + '/startups?' + URI.encode_www_form(params)
    results = get_data fetch_url
    unless results.present?
      return false
    end

    results["startups"].each do |startup|
      if startup["hidden"]
        next
      else
        return {
                :name => startup["name"],
                :summary =>startup["high_concept"]
                }
        break
      end
    end
  end

  def get_data url
    resp = HTTParty.get url
    JSON.parse(resp.body)
  end
end

startup = ARGV[0]
unless startup.present?
  puts 'Please provide a startup name..'
end

angel = Angel.new
similar = angel.get_similar startup
if similar.present?
  puts "Name: #{similar[:name]}"
  puts "Summary: #{similar[:summary]}"
else
  puts "Unable to find similar startup for #{startup}"
end
