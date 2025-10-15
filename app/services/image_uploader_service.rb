require 'curb'
require 'json'

class ImageUploaderService
  def initialize(image_url)
    @api_key = ENV['FREEIMAGE_API_KEY']
    @image_url = image_url
    @url = 'https://freeimage.host/api/1/upload'
  end

  def upload_image
    c = Curl::Easy.new(@url)
    c.http_post(
      Curl::PostField.content('key', @api_key),
      Curl::PostField.content('source', @image_url),
      Curl::PostField.content('format', 'json')
    )
    
    # Parse the JSON response
    response = JSON.parse(c.body_str)
    
    # Check if the request was successful
    if response["status_code"] == 200
      puts "Image uploaded successfully!"
      puts "Image URL: #{response['image']['url']}"
      response['image']['url']
    else
      puts "Failed to upload image: #{response['status_txt']}"
    end
  end
end