FROM amazon/aws-lambda-ruby:2.7
RUN yum install -y tar
COPY lib .
RUN bundle
