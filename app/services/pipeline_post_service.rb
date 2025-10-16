class PipelinePostService
  MAX_RETRIES = 10
  POST_STATUS = "publish"

  def initialize(gemini_service: GeminiService.new, blogger_service: WordpressPostService)
    @gemini_service = gemini_service
    @blogger_service = blogger_service
  end

  def call
    MAX_RETRIES.times do |attempt|
      article = generate_article
      title, content, keywords = article.values_at(:title, :content, :keywords)

      if post_exists?(title)
        puts "⚠️  Duplicate title '#{title}' detected (attempt #{attempt + 1}). Retrying..."
        next
      end

      return publish_post(title, content, keywords)
    end

    puts "❌ Unable to generate a unique title after #{MAX_RETRIES} attempts. Aborting post creation."
    nil
  end

  private

  def generate_article
    @gemini_service.generate_post
  end

  def publish_post(title, content, keywords)
    post = @blogger_service.new(title: title, content: content, status: POST_STATUS, keywords: keywords).call

    if post[:success] == false
      raise StandardError, "Failed to publish post '#{title}'"
    end

    puts "✅ Post '#{title}' published successfully at: #{post[:link]}"
    post
  end

  def post_exists?(title)
    @blogger_service.new.send(:post_exists?, title)
  rescue Google::Apis::ClientError => e
    puts "⚠️ Error checking for existing posts: #{e.message}"
    false
  end
end