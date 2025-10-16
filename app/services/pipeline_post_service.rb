class PipelinePostService
  def initialize(gemini_service: GeminiService.new, blogger_service: WordpressPostService)
    @gemini_service = gemini_service
    @blogger_service = blogger_service
  end

  def call
    retries = 0
    article = generate_article
    title = article[:title]
    content = article[:content]
    keywords = article[:keywords]

    # Loop up to 10 times to check for unique title and regenerate article if needed
    while retries < 10
      if post_exists?(title)
        retries += 1
        puts "Post with title '#{title}' already exists. Retrying with a new title."

        # Append the retry count to the title to make it unique
        title = "#{article[:title]}_#{retries}"

        # Regenerate the article
        article = generate_article
        title = article[:title]  # Update title from regenerated article
        content = article[:content]  # Update content from regenerated article
      else
        break
      end
    end

    # If we hit the retry limit, exit with a message
    if retries == 10
      puts "Unable to find a unique title after 10 attempts. Skipping creation."
      return
    end

    # Post the article with the unique title
    @blogger_service.new(title: title, content: content, status: "publish", keywords: keywords).call
  end

  private

  def generate_article
    # Generate a new article with title and content
    @gemini_service.generate_post
  end

  def post_exists?(title)
    # Check if the post with the given title already exists
    @blogger_service.new.send(:post_exists?, title)
  rescue Google::Apis::ClientError => e
    puts "An error occurred while fetching posts: #{e.message}"
    false
  end
end
