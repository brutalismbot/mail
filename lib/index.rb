require "json"
require "logger"

require "aws-sdk-s3"
require "aws-sdk-sesv2"
require "mail"

$logger = Logger.new($stdout, progname: "-", formatter: -> (lvl, t, name, msg) { "#{ lvl } #{ name } #{ msg }\n" })

def handler(name, &block)
  define_method(name) do |event:nil, context:nil|
    $logger.progname = context.nil? ? "-" : "RequestId: #{ context.aws_request_id }"
    $logger.info("EVENT #{ event.to_json }")
    result = yield(event, context) if block_given?
    $logger.info("RETURN #{ result.to_json }")
    result
  end
end

def each_message_in(event, &block)
  event.fetch("Records").each do |record|
    yield JSON.parse record.dig "Sns", "Message"
  end
end

DESTINATIONS = ENV["DESTINATIONS"].to_s.split(/,/)

S3  = Aws::S3::Client.new
SES = Aws::SESV2::Client.new

handler :handler do |event|
  each_message_in event do |message|
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
    SES.send_email content:            { raw: { data: mail.to_s } },
                   destination:        { to_addresses: mail.to },
                   from_email_address: mail.from.first,
                   reply_to_addresses: mail.reply_to
  end
end
