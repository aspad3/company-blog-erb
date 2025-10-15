class GoogleAccessService
  def initialize
    @google_access_token = ENV['GOOGLE_ACCESS_TOKEN']
    @google_refresh_token = ENV['GOOGLE_REFRESH_TOKEN']
  end

  def perform
    token_expired? ? refresh_google_access_token : @google_access_token
  end

  private

  def token_expired?
    return true unless @google_access_token.present?

    uri = URI("https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=#{@google_access_token}")
    response = Net::HTTP.get_response(uri)

    !response.is_a?(Net::HTTPSuccess)
  end

  def refresh_google_access_token
    return nil unless @google_refresh_token.present?

    uri = URI('https://oauth2.googleapis.com/token')
    params = {
      'client_id' => ENV['GOOGLE_CLIENT_ID'],
      'client_secret' => ENV['GOOGLE_CLIENT_SECRET'],
      'refresh_token' => @google_refresh_token,
      'grant_type' => 'refresh_token'
    }

    response = Net::HTTP.post_form(uri, params)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      data['access_token']
    else
      log_error(response)
      nil
    end
  end

  def log_error(response)
    Rails.logger.error("Failed to refresh access token: #{response.body}")
  end
end