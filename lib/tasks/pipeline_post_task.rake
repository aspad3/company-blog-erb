namespace :pipeline_post do
  desc "Generate and post an article using the PipelinePostService"
  task :create_post => :environment do
    # Menjalankan PipelinePostService
    begin
      service = PipelinePostService.new
      service.call
      puts "Post created successfully"
    rescue => e
      puts "Error: #{e.message}"
    end
  end
end
