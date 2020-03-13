ARG RUBY=2.7
ARG TERRAFORM=latest

FROM lambci/lambda:build-ruby${RUBY} AS build
COPY Gemfile* /var/task/
RUN bundle config --local path vendor/bundle/
RUN bundle config --local silence_root_warning 1
RUN bundle config --local without development
RUN bundle
COPY lambda.rb .
RUN zip -r lambda.zip *

FROM hashicorp/terraform:${TERRAFORM} AS plan
WORKDIR /var/task/
COPY . .
COPY --from=build /var/task/ .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
RUN terraform fmt -check
RUN terraform init
ARG TF_VAR_destinations
ARG TF_VAR_release
RUN terraform plan -out terraform.zip
CMD ["apply", "terraform.zip"]
