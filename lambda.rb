require "json"

require "aws-sdk-s3"
require "aws-sdk-sesv2"
require "mail"

DESTINATIONS = ENV["DESTINATIONS"].to_s.split(/,/)

S3  = Aws::S3::Client.new
SES = Aws::SESV2::Client.new

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

    # Massage message for SES
    mail             = Mail.read_from_string object.body.read
    mail.to          = DESTINATIONS
    mail.reply_to    = mail.from
    mail.from        = "Brutalismbot Help <no-reply@brutalismbot.com>"
    mail.return_path = "<no-reply@brutalismbot.com>"

    # Forward message to `DESTINATIONS`
    SES.send_email(content: {raw: {data: mail.to_s}})
  end
end
