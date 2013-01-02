# @Author   : Romain Boulay
# @Date     : 01/2013
# @Link     : http://romainboulay.com


class BasecampFileDownloads
    require 'net/http'
    require 'net/https'
    require 'httpclient'
    
    require 'hpricot'
    require 'basecamp'
    require 'progressbar'
    require 'highline/import'
    
    attr_accessor :host, :domain, :username, :password
    
    
    def initialize
        @host = ask("Basecamp URL: ")
        @host.gsub!("https://", "")
        @host.gsub!("http://", "")
        @domain = "https://#{@host}"
        
        @username = ask("Username: ")
        @password = ask("Password: ") {|q| q.echo = false} # Hide the password
        
        Basecamp.establish_connection!(@host, @username, @password, true, true)
    end
    
    
    def file_listings(project_id, num)
        client = HTTPClient.new()
        client.set_auth(@domain, @username, @password)
        
        if num then
            results = client.get_content("https://#{@username}:#{@password}@#{@host}/projects/#{project_id}/attachments.xml?n=#{num}")
            else
            results = client.get_content("https://#{@username}:#{@password}@#{@host}/projects/#{project_id}/attachments.xml")
        end
        
        doc = Hpricot::XML(results)
        return (doc/"download-url").map{|f| f.inner_html}
    end
    
    
    def download_files_in_project(project, projectid, num=nil)
        files = file_listings(projectid,num)
        dirname = project.name.gsub(/\//,"")
        files.each do |file|
            filename = file.gsub(/.*\/([^\/]*?)/,"\\1")
            print "\n****  downloading file: #{filename}"
            
            unless File.exists?("./#{dirname}")
                Dir.mkdir("#{dirname}")
            end
            
            while File.exists?("./#{dirname}/#{filename}")
                filename = filename.gsub(/\./,"-cpy.")
            end
            
            destPath = "./#{dirname}/#{filename}"
            download(file, destPath)
        end
    end
    
    
    def download_files
        Basecamp::Project.find(:all).each do |project|
            puts "**********  downloading project: #{project.name}"
            download_files_in_project(project, project.id)
        end
    end
    
    
    def download(srcPath, destPath)
        # Set up connection, explicitly set SSL
        uri = URI.parse(@domain)
        http = Net::HTTP.new(uri.host, 443)
        http.use_ssl = true
        
        # Ignore certificate issues, for self-issued certs. (Remove this otherwise)
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        
        # Create the request and authenticate
        print " (@url : #{srcPath})"
        puts
        
        request = Net::HTTP::Get.new(srcPath)
        request.basic_auth(@username, @password)
        
        # Open the file for writing
        destFile = open(destPath, "wb")
        
        # Download the file
        begin
            http.request(request) do |response|
                fileSize = response['Content-Length'].to_i
                puts "File Size: " + fileSize.to_s
                bytesTransferred = 0
                
                # Initialize the progress bar
                pbar = ProgressBar.new("Downloading", fileSize)
                pbar.file_transfer_mode # Set file transfer mode, to show speed/file size
                
                # Read the data as it comes in
                response.read_body do |part|
                    # Update the total bytes transferred and the progress bar
                    bytesTransferred += part.length
                    pbar.set(bytesTransferred)
                    
                    # Write the data direct to file
                    destFile.write(part)
                end
                pbar.finish
            end
            ensure
            destFile.close
        end
    end
    
end

# Main
bc = BasecampFileDownloads.new()
bc.download_files
