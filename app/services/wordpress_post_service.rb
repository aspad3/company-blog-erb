# app/services/wordpress/post_creator_service.rb
require 'net/http'
require 'uri'
require 'json'
require 'base64'
require 'mime/types'

class WordpressPostService
  WORDPRESS_POSTS_API_URL = "https://doterb.com/wp-json/wp/v2/posts"
  WORDPRESS_MEDIA_API_URL = "https://doterb.com/wp-json/wp/v2/media"

  SEO_FOCUS_KEYWORD_FIELD = :_yoast_wpseo_focuskw

  # Ganti `image_path` menjadi `image_source` agar lebih fleksibel (bisa path atau URL)
  def initialize(title: nil, content: nil, status: "draft", slug: nil, categories: [1], tags: [39], keywords: [], image_url: nil)
    @title = title
    @content = content
    @status = status
    @slug = slug
    @categories = categories
    @tags = tags
    @keywords = Array(keywords).compact.reject(&:empty?)
    @image_source = image_url # <-- Sumber gambar (URL atau path)
  end

  def call
    # Langkah 1: Upload gambar jika ada, dan dapatkan ID-nya
    media_id = upload_featured_image(@image_source) if @image_source.present?

    # Langkah 2: Buat postingan
    uri = URI.parse(WORDPRESS_POSTS_API_URL)
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request["Authorization"] = "Basic #{encoded_auth}"
    request.body = request_body(media_id).to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    parse_response(response)
  end

  private

  # ✨ METHOD UPLOAD DIMODIFIKASI UNTUK MENANGANI URL ✨
  def upload_featured_image(source)
    image_data = nil
    filename = nil

    # Cek apakah source adalah URL atau path file lokal
    if source.start_with?('http://', 'https://')
      # --- Logika untuk URL ---
      puts "Downloading image from URL: #{source}"
      uri = URI.parse(source)
      response = Net::HTTP.get_response(uri)
      if response.is_a?(Net::HTTPSuccess)
        image_data = response.body
        filename = File.basename(uri.path)
      else
        puts "Gagal download gambar dari URL. Status: #{response.code}"
        return nil
      end
    elsif File.exist?(source)
      # --- Logika untuk file lokal (sama seperti sebelumnya) ---
      puts "Reading image from local path: #{source}"
      image_data = File.read(source)
      filename = File.basename(source)
    else
      puts "Sumber gambar tidak valid atau file tidak ditemukan: #{source}"
      return nil
    end

    # --- Proses upload ke WordPress ---
    uri = URI.parse(WORDPRESS_MEDIA_API_URL)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Basic #{encoded_auth}"
    request['Content-Disposition'] = "attachment; filename=\"#{filename}\""
    request.content_type = MIME::Types.type_for(filename).first.content_type
    request.body = image_data

    upload_response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if upload_response.is_a?(Net::HTTPSuccess)
      JSON.parse(upload_response.body)["id"]
    else
      puts "Gagal upload gambar ke WordPress: #{upload_response.body}"
      nil
    end
  rescue => e
    puts "Error saat memproses gambar: #{e.message}"
    nil
  end

  def encoded_auth
    username = ENV.fetch("WP_USERNAME", "admin")
    app_password = ENV.fetch("WP_APP_PASSWORD", "ganti dengan password aplikasi Anda")
    Base64.strict_encode64("#{username}:#{app_password}")
  end

  def request_body(media_id = nil)
    body = {
      title: @title,
      content: @content,
      status: @status,
      slug: @slug,
      categories: @categories,
      tags: @tags,
      featured_media: media_id
    }
    if @keywords.any?
      body[:meta] = { SEO_FOCUS_KEYWORD_FIELD => @keywords.first }
    end
    body.compact
  end

  def parse_response(response)
    case response
    when Net::HTTPSuccess
      json = JSON.parse(response.body)
      { success: true, id: json["id"], link: json["link"], title: json.dig("title", "rendered") }
    else
      { success: false, code: response.code, message: response.body }
    end
  rescue JSON::ParserError => e
    { success: false, code: response.code, message: "Invalid JSON response: #{e.message}" }
  end

  def post_exists?(title)
    # Jangan lakukan pencarian jika judul kosong
    return false if title.to_s.strip.empty?

    # Lakukan URL encoding pada judul untuk keamanan query
    encoded_title = URI.encode_www_form_component(title)
    
    # Buat URI untuk pencarian berdasarkan judul
    uri = URI.parse("#{WORDPRESS_POSTS_API_URL}?search=#{encoded_title}&per_page=1")
    
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Basic #{encoded_auth}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    # Jika request sukses, parse JSON dan cek hasilnya
    if response.is_a?(Net::HTTPSuccess)
      results = JSON.parse(response.body)
      # Jika array hasil tidak kosong, berarti post ditemukan
      return !results.empty?
    end

    # Jika terjadi error atau post tidak ditemukan, kembalikan false
    false
  rescue JSON::ParserError => e
    puts "Error parsing JSON saat mengecek post: #{e.message}"
    false
  end
end