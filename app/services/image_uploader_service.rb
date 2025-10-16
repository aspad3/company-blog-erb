require 'curb'
require 'json'

class ImageUploaderService
  API_URL = 'https://freeimage.host/api/1/upload'

  def initialize(base64_image)
    @api_key = ENV['FREEIMAGE_API_KEY']
    @base64_image = base64_image
  end

  def upload_image
    c = Curl::Easy.new(API_URL)
    c.multipart_form_post = true

    c.http_post(
      Curl::PostField.content('key', @api_key),
      Curl::PostField.content('action', 'upload'),
      Curl::PostField.content('source', @base64_image),
      Curl::PostField.content('format', 'json')
    )

    response = JSON.parse(c.body_str) rescue {}

    if response["status_code"] == 200
      image_url = response.dig('image', 'url')
      puts "✅ Image uploaded successfully!"
      puts "🌐 Image URL: #{image_url}"
      image_url
    else
      puts "❌ Failed to upload image: #{response['status_txt'] || 'Unknown error'}"
      puts "Response: #{response.inspect}"
      nil
    end
  end
end
