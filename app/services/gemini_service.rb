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

    # 🎯 Relevant themes for Doterb.com (IT Service & Web Development)
    @themes = load_themes_from_file("themes.txt")

    # 📸 Image categories relevant to IT and business
    @image_categories = ["tech", "business", "data", "office", "innovation", "startup"]
  end

  def generate_post
    random_theme = @themes.sample
    random_quote = [
      "\"A website is not just a display it's your company's digital trust representation.\"",
      "\"Digital transformation is not an option, it's a necessity to stay relevant.\"",
      "\"Efficient systems are born from collaboration between strategy and technology.\"",
      "\"Technology helps businesses grow faster and smarter.\""
    ].sample

    timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    random_id = SecureRandom.hex(4)

    # 📷 Fetch a random image from Unsplash
    random_category = @image_categories.sample
    image_url = "https://source.unsplash.com/800x400/?#{random_category}"

    # 🖼️ Generate image via AI (if available)
    image_result = TextToImageService.generate_image_base64(random_theme)
    image_url = ImageUploaderService.new(image_result[:base64_image]).upload_image if image_result[:success]

    # 🧠 Prompt for Gemini API
    prompt = <<~PROMPT
      Write a complete blog article in **English only** for a professional IT service company called **Doterb** (https://doterb.com).

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
      "If your business needs an efficient website or digital system, contact the Doterb team today."
    PROMPT

    body = {
      contents: [{ parts: [{ text: prompt }] }]
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

        # Extract only the <div class="article-wrapper">...</div> part
        if content =~ /<div.*<\/div>/m
          content = content.strip.match(/<div.*<\/div>/m)[0]
        end

        # Insert image at the top of the article
        content_with_image = content.sub(
          '<div',
          "<div style=\"text-align:center; margin:20px 0;\"><img src=\"#{image_url}\" alt=\"Random image\" loading=\"lazy\" style=\"display:block; margin:0 auto; width:100%; max-width:300px; height:auto; border-radius:10px; object-fit:contain;\" /></div><div"
        )

        title = extract_title_from_html(content_with_image)
        content_final = sanitize_html(content_with_image)
        keywords = generate_keywords(random_theme, content_final)

        return {
          title: title,
          content: content_final,
          theme: random_theme,
          keywords: keywords,
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
    doc.at('h1')&.text || "Technology Article by Doterb"
  end

  def sanitize_html(html)
    Nokogiri::HTML.fragment(html).to_html
  end

  def load_themes_from_file(file_path)
    File.readlines(file_path).map(&:strip).reject(&:empty?)
  end

  # ✨ Automatically generate keywords from the theme and article content
  def generate_keywords(theme, content)
    base_keywords = [
      "technology", "web development", "digital transformation", "IT solutions", 
      "business website", "information systems", "startup", "innovation", "Doterb"
    ]

    theme_words = theme.downcase.split(/\W+/).uniq
    content_words = Nokogiri::HTML(content).text.downcase.scan(/\b[a-zA-Z]+\b/)
    common_words = (theme_words + content_words).uniq

    # Select relevant words (longer than 4 letters, not common stopwords)
    filtered = common_words.select { |w| w.length > 4 && !%w[untuk dalam dengan yang adalah pada].include?(w) }
    (base_keywords + filtered.sample(5)).uniq.first(10)
  end
end
