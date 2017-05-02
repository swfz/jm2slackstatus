#!/usr/bin/env ruby

require 'nokogiri'
require 'capybara'
require 'capybara/poltergeist'
require 'uri'
require 'dotenv'
require 'awesome_print'
require 'time'
require 'net/http'

class Slack
  attr_reader :token
  SLACK_API_URL = 'https://slack.com/api/users.profile.set'

  def initialize
    @token = ENV["SLACK_TOKEN"]
  end

  def update(status)
    url = URI.parse(SLACK_API_URL)
    params = {profile: {status_text: status.status_text, status_emoji: status.status_emoji}.to_json.to_s, token: token}
    http = Net::HTTP.new(url.host,url.port)
    http.set_debug_output $stderr
    http.use_ssl = true
    http.start do
      req = Net::HTTP::Post.new(url.path)
      req.set_form_data(params)
      http.request(req)
    end
  end
end

class Jmotto
  LOGIN_URL='https://www1.j-motto.co.jp/fw/dfw/po80/portal/jsp/J10201.jsp?https://www1.j-motto.co.jp/fw/dfw/gws/cgi-bin/aspioffice/iocjmtgw.cgi?cmd=login'

  attr_reader :session, :member_id, :user_id, :password

  def initialize
    Capybara.default_selector = :xpath
    Capybara.register_driver :poltergeist do |app|
      # Capybara::Poltergeist::Driver.new(app, inspector: true)
      Capybara::Poltergeist::Driver.new(app, {:js_errors => false, :timeout => 3000 })
    end

    @session   = Capybara::Session.new(:poltergeist)
    @member_id = ENV["JMOTTO_MEMBER_ID"]
    @user_id   = ENV["JMOTTO_USER_ID"]
    @password  = ENV["JMOTTO_PASSWORD"]
  end

  def get_current_schedules
    session.visit LOGIN_URL
    sleep 1
    session.fill_in 'memberID', with: member_id
    session.fill_in 'userID', with: user_id
    session.fill_in 'password', with: password

    session.save_screenshot('./ss/login/login.png')
    session.click_button('ログイン')

    sleep 6
    session.save_screenshot('./ss/login/after.png')

    doc = Nokogiri::HTML.parse(session.html)

    current_schedules = []
    doc.xpath('//td[@class="cal-day co-today"]//div[@class="cal-item-box"]').each{|node|
      ap node
      schedule = node2hash(node)
      current_schedules.push(schedule) if Time.now().between?(schedule[:terms][0],schedule[:terms][1])
    }

    current_schedules
  end

  def fix_category(node)
    # jmotto
    name = node.xpath('.//a').text
    if !node.xpath('.//a/span[@class="sch-ictype1-scr"]').empty?
      return 'secret'
    elsif name.include?('休暇')
      return 'rest'
    else
      return 'meeting'
    end

  end

  def node2hash(node)
    name     = node.xpath('.//a').text
    term_str = node.xpath('.//span[@class="cal-term-text"]').text
    term     = term_str.split(' - ').map{|t| Time.parse(t)}
    category = fix_category(node)
    ap category

    {
      name:     (category == 'secret') ? '' : name,
      terms:    term,
      term_str: term_str,
      category: category,
    }
  end
end

class Status
  attr_reader :status_emoji, :status_text
  CATEGORIES = {
    remote: ":house:",
    meeting: ":speech_balloon:",
    rest: ":palm_tree:",
    secret: ":speech_baloon:",
  }

  def initialize
    @status_emoji = ":computer:"
    @status_text  = "working..."
  end

  def schedule_map(schedule)
    CATEGORIES[schedule[:category].to_sym]
  end

  def fix_status(schedules)
    return if schedules.empty?

    @status_emoji = schedule_map(schedules.first)
    @status_text  = schedules.map{|s| s[:name]}.join(' ')
  end
end

Dotenv.load
current_schedules = Jmotto.new().get_current_schedules
status = Status.new()
status.fix_status(current_schedules)

Slack.new().update(status)
