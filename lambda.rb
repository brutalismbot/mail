require "aws-sdk-s3"
require "aws-sdk-ses"
require "mail"

DESTINATIONS = ENV["DESTINATIONS"].split /,/

S3  = Aws::S3::Client.new
SES = Aws::SES::Client.new

module Event
  class SNS < Hash
    include Enumerable

    def each
      puts "EVENT #{to_json}"
      dig("Records").each do |record|
        yield JSON.parse record.dig("Sns", "Message")
      end
    end
  end
end

def handler(event:, context:)
  Event::SNS[event].map do |message|
    # Get message from S3
    bucket = message.dig "receipt", "action", "bucketName"
    key    = message.dig "receipt", "action", "objectKey"
    object = S3.get_object bucket: bucket, key: key
    data   = object.body.read

    # Massage message for SES
    mail             = Mail.read_from_string data
    mail.to          = DESTINATIONS
    mail.reply_to    = mail[:from].value
    mail.from        = mail[:from].value.sub /<.*?@.*?>/, "<no-reply@brutalismbot.com>"
    mail.return_path = "<no-reply@brutalismbot.com>"

    # Forward message to `DESTINATIONS`
    SES.send_raw_email raw_message: {data: mail.to_s}
  end
end
