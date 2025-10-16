# app/services/wordpress/post_creator_service.rb
require 'net/http'
require 'uri'
require 'json'
require 'base64'

class WordpressPostService
  WORDPRESS_API_URL = "https://doterb.com/wp-json/wp/v2/posts"

  # Ganti dengan key yang sesuai plugin Anda:
  # - Untuk Yoast SEO: :_yoast_wpseo_focuskw
  # - Untuk Rank Math: :rank_math_focus_keyword
  SEO_FOCUS_KEYWORD_FIELD = :_yoast_wpseo_focuskw # << GANTI DI SINI JIKA PAKAI RANK MATH

  def initialize(title: nil, content: nil, status: "draft", slug: nil, categories: [1], tags: [39], keywords: [])
    @title = title
    @content = content
    @status = status
    @slug = slug
    @categories = categories
    @tags = tags
    @keywords = Array(keywords).compact.reject(&:empty?) # Pastikan keywords valid
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

  def encoded_auth
    # Pastikan environment variables sudah di-set
    username = ENV.fetch("WP_USERNAME", "admin")
    app_password = ENV.fetch("WP_APP_PASSWORD", "ganti dengan password aplikasi Anda") # Harap ganti!
    Base64.strict_encode64("#{username}:#{app_password}")
  end

  def request_body
    body = {
      title: @title,
      content: @content,
      status: @status,
      slug: @slug,
      categories: @categories,
      tags: @tags
    }

    # ✨ Kirim meta field untuk SEO jika keywords ada
    if @keywords.any?
      body[:meta] = {
        # Menggunakan konstanta agar mudah diubah sesuai plugin SEO
        SEO_FOCUS_KEYWORD_FIELD => @keywords.first
      }
    end

    body.compact
  end

  def parse_response(response)
    case response
    when Net::HTTPSuccess
      json = JSON.parse(response.body)
      {
        success: true,
        id: json["id"],
        link: json["link"],
        title: json.dig("title", "rendered")
      }
    else
      {
        success: false,
        code: response.code,
        message: response.body
      }
    end
  rescue JSON::ParserError => e
    { success: false, code: response.code, message: "Invalid JSON response: #{e.message}" }
  end

  # Metode post_exists? Anda sudah cukup baik, tidak perlu diubah.
  def post_exists?(title)
    # ... (kode Anda sebelumnya)
  end
end