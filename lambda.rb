require "json"

require "aws-sdk-s3"
require "aws-sdk-ses"
require "mail"

DESTINATIONS = ENV["DESTINATIONS"].to_s.split(/,/)

S3  = Aws::S3::Client.new
SES = Aws::SES::Client.new

def each_message(event)
  puts "EVENT #{event.to_json}"
  event.fetch("Records").each do |record|
    yield JSON.parse record.dig "Sns", "Message"
  end
end

def handler(event:, context:nil)
  each_message event do |message|
    # Get message from S3
    bucket = message.dig "receipt", "action", "bucketName"
    key    = message.dig "receipt", "action", "objectKey"
    object = S3.get_object bucket: bucket, key: key
    data   = object.body.read

    # Massage message for SES
    mail             = Mail.read_from_string data
    mail.to          = DESTINATIONS
    mail.reply_to    = mail[:from].value
    mail.from        = "Brutalismbot Help <no-reply@brutalismbot.com>"
    mail.return_path = "<no-reply@brutalismbot.com>"

    # Forward message to `DESTINATIONS`
    SES.send_raw_email raw_message: {data: mail.to_s}
  end
end
