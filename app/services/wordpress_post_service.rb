# app/services/wordpress/post_creator_service.rb
require 'net/http'
require 'uri'
require 'json'
require 'base64'

class WordpressPostService
  WORDPRESS_API_URL = "https://doterb.com/wp-json/wp/v2/posts"

  def initialize(title:nil, content:nil, status: "draft", slug: nil, categories: [], tags: [], featured_media: nil)
    @title = title
    @content = content
    @status = status
    @slug = slug
    @categories = categories
    @tags = tags
    @featured_media = featured_media
  end

  def call
    uri = URI.parse(WORDPRESS_API_URL)
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request["Authorization"] = "Basic #{encoded_auth}"
    request.body = request_body.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    parse_response(response)
  end

  private

  # 👉 ubah sesuai user & application password WordPress kamu
  def encoded_auth
    username = ENV.fetch("WP_USERNAME", "admin")
    app_password = ENV.fetch("WP_APP_PASSWORD", "abcd efgh ijkl mnop")
    Base64.strict_encode64("#{username}:#{app_password}")
  end

  def request_body
    {
      title: @title,
      content: @content,
      status: @status,
      slug: @slug,
      categories: @categories,
      tags: @tags,
      featured_media: @featured_media
    }.compact
  end

  def parse_response(response)
    case response
    when Net::HTTPSuccess
      json = JSON.parse(response.body)
      {
        success: true,
        id: json["id"],
        link: json["link"],
        title: json["title"]["rendered"]
      }
    else
      {
        success: false,
        code: response.code,
        message: response.body
      }
    end
  end

  # 🔍 Cek apakah post dengan judul yang sama sudah ada
  def post_exists?(title)
    uri = URI.parse("#{WORDPRESS_API_URL}?search=#{URI.encode_www_form_component(title)}&per_page=5")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Basic #{encoded_auth}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    return false unless response.is_a?(Net::HTTPSuccess)

    posts = JSON.parse(response.body)
    posts.any? { |post| post.dig("title", "rendered")&.strip&.casecmp?(title.strip) }
  rescue => e
    puts "Error checking post existence: #{e.message}"
    false
  end
end

