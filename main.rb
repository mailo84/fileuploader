require "sinatra"
require "fileutils"
require "mail"
require "russian"
require "digest"

Options = {
  :mail => {
    :address => "smtp.gmail.com",
    :port => 587,
    :user_name => "login@gmail.com",
    :password => "password",
    :authentication => "plain",
    :enable_starttls_auto => true,
  },
  :common => {
    :upload_dir => "/home/azmar/Projects/upload",
    :mail_from => "login@gmail.com",
    :mail_to => "destination@yandex.ru",
    :secure_link_secret => "asdf",
    :secure_link_location => "http://localhost/sig",
  },
}

Mail.defaults do
  delivery_method :smtp, Options[:mail]
end

def generate_secure_link(uri)
  secret = Options[:common][:secure_link_secret]
  seclink_str = "#{uri}#{secret}"
  digest = Digest::MD5.hexdigest seclink_str
  "#{Options[:common][:secure_link_location]}/#{digest}/#{uri}"
end

get "/" do
  send_file File.expand_path("form.html", settings.public_folder)
end

post "/upload" do
  first_name = Russian.translit params["first_name"]
  last_name = Russian.translit params["last_name"]
  role = params["role"]
  comment = params["comment"]
  file_path = "upload/#{first_name}_#{last_name}/"
  file_list = Array.new

  FileUtils.mkdir_p file_path

  #binding.pry
  params.keys.select { |key| key =~ /^uploaded_file/ }.each do |file|
    filename = params[file][:filename]
    tmpfile = params[file][:tempfile]
    fullpath = "#{file_path}#{filename}"
    File.open(fullpath, "wb") do |f|
      f.write tmpfile.read
      file_list << generate_secure_link(fullpath)
    end
  end

  mailbody = erb :mailtemplate, locals: {
                                  name: "#{role} #{first_name} #{last_name}",
                                  comment: comment,
                                  file_list: file_list,
                                }

  mail = Mail.deliver do
    from Options[:common][:mail_from]
    to Options[:common][:mail_to]
    subject "New files from #{role} #{first_name} #{last_name}"
    html_part do
      content_type "text/html; charset=UTF-8"
      body mailbody
    end
  end

  mailbody
end
