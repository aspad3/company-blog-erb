# app/services/gemini_service.rb
require 'curl'
require 'json'
require 'securerandom'
require 'nokogiri'
require 'date'

class GeminiService
  def initialize
    @google_gemini_api_url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
    @api_key = ENV['GOOGLE_GEMINI_API_KEY']

    # 🎯 Tema-tema relevan untuk Doterb.com (IT Service & Web Development)
    @themes = load_themes_from_file("themes.txt")

    # 📸 Gambar yang relevan dengan tema IT dan bisnis
    @image_categories = ["tech", "business", "data", "office", "innovation", "startup"]
  end

  def generate_post
    random_theme = @themes.sample
    random_quote = [
      "\"Website bukan sekadar tampilan, tapi representasi kepercayaan digital perusahaan Anda.\"",
      "\"Transformasi digital bukan pilihan, tapi kebutuhan untuk tetap relevan.\"",
      "\"Sistem yang efisien lahir dari kolaborasi antara strategi dan teknologi.\"",
      "\"Teknologi membantu bisnis berkembang lebih cepat dan cerdas.\""
    ].sample

    timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    random_id = SecureRandom.hex(4)

    # 📷 Ambil gambar acak dari Unsplash
    random_category = @image_categories.sample
    image_url = "https://source.unsplash.com/800x400/?#{random_category}"


    # Generate image based on the random theme
    image_result = TextToImageService.generate_image_base64(random_theme)
    # Check if the image generation was successful
    image_url = ImageUploaderService.new(image_result[:base64_image]).upload_image if image_result[:success]


    # 🧠 Prompt AI
    prompt = <<~PROMPT
      Write a complete blog article in **Indonesian only** for a professional IT service company called **Doterb** (https://doterb.com).

      Company background:
      - Doterb is a web development and IT solutions company.
      - They provide website creation, system integration, and digital transformation services.

      Article theme: #{random_theme}
      Relevant quote to include: #{random_quote}
      Generated at: #{timestamp}, ID: #{random_id}

      === Structure ===
      Return the article wrapped inside a single <div class="article-wrapper"> ... </div>, 
      without <html>, <head>, or <body> tags.

      Inside the <div> must include:
      - <h1>: article title
      - a short introduction paragraph (<p>)
      - Table of Contents generated from <h2> headings
      - main sections using <h2> and <h3>
      - a FAQ section with at least 3 Q&A related to the topic
      - a natural call-to-action paragraph at the end, inviting readers to contact Doterb

      Style:
      - Professional, modern, and informative
      - Written as if it’s from a real IT service company
      - Avoid overly promotional tone, focus on providing value and insights

      Example CTA:
      "Jika bisnis Anda ingin memiliki website atau sistem digital yang efisien, hubungi tim Doterb hari ini."
    PROMPT

    body = {
      contents: [
        {
          parts: [
            { text: prompt }
          ]
        }
      ]
    }.to_json

    c = Curl::Easy.new(@google_gemini_api_url)
    c.headers['Content-Type'] = 'application/json'
    c.headers['X-goog-api-key'] = @api_key
    c.post_body = body

    begin
      c.perform
      if c.response_code == 200
        parsed = JSON.parse(c.body_str)
        content = parsed.dig("candidates", 0, "content", "parts", 0, "text")
        raise "No content found" unless content

        # Ambil hanya isi <div class="article-wrapper">...</div>
        if content =~ /<div.*<\/div>/m
          content = content.strip.match(/<div.*<\/div>/m)[0]
        end

        # Tambahkan gambar di awal artikel
        content_with_image = content.sub('<div', "<div><img src=\"#{image_url}\" alt=\"Tech image\" loading=\"lazy\"><div")

        title = extract_title_from_html(content_with_image)
        content_final = sanitize_html(content_with_image)

        return {
          title: title,
          content: content_final,
          theme: random_theme,
          generated_at: timestamp
        }
      else
        raise "Failed to generate post: #{c.body_str}"
      end
    rescue StandardError => e
      puts "Error: #{e.message}"
      raise
    end
  end

  private

  def extract_title_from_html(html)
    doc = Nokogiri::HTML.fragment(html)
    doc.at('h1')&.text || "Artikel Teknologi dari Doterb"
  end

  def sanitize_html(html)
    Nokogiri::HTML.fragment(html).to_html
  end

  def load_themes_from_file(file_path)
    File.readlines(file_path).map(&:strip).reject(&:empty?)
  end
end
