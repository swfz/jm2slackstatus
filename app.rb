#!/usr/bin/env ruby

require 'nokogiri'
require 'capybara'
require 'capybara/poltergeist'
require 'uri'
require 'dotenv'
require 'awesome_print'

class Slack
  attr_reader :token
  def initialize
    @token = ENV["SLACK_TOKEN"]
  end

  def update(schedule)
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

  def get_current_schedule
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

    ap doc
    ap '----------'
    ap doc.xpath('//td[@class="cal-day co-today"]')
  end
end

Dotenv.load
current_schedule = Jmotto.new().get_current_schedule
# Slack.new().update(current_schedule)
