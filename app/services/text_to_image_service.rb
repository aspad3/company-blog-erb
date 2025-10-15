# app/services/clipdrop_service.rb

require 'curb'
require 'base64'

class TextToImageService
  # Define constants for the API endpoint and key
  API_URL = "https://clipdrop-api.co/text-to-image/v1".freeze
  
  # Fetch the API key from environment variables.
  # `fetch` will raise an error if the key isn't set, which is good practice.
  API_KEY = ENV.fetch('CLIPDROP_API_KEY')

  # The main class method to generate the image.
  # It accepts a prompt and returns a hash with the result.
  def self.generate_image_base64(prompt)
    # Initialize a Curl::Easy object for the request
    http_client = Curl::Easy.new(API_URL)
    prompt = "#{prompt} di indonesia"

    # Set the request to be a multipart form POST, as required by the API
    http_client.multipart_form_post = true

    # Set the required API key in the request headers
    http_client.headers['x-api-key'] = API_KEY

    # Create the form field for the prompt
    prompt_field = Curl::PostField.content('prompt', prompt)

    # Perform the POST request, passing the prompt field
    http_client.http_post(prompt_field)

    # Check the HTTP response code to see if the request was successful
    if http_client.response_code == 200
      # The raw binary image data is in the response body
      image_data = http_client.body_str
      
      # Encode the raw binary data into a Base64 string
      base64_image = Base64.strict_encode64(image_data)
      
      { success: true, base64_image: base64_image }
    else
      # If the request failed, return an error message
      { success: false, error: "API Error: #{http_client.response_code} - #{http_client.body_str}" }
    end
  end
end