ARG RUNTIME=ruby2.5
ARG TERRAFORM=latest

FROM lambci/lambda:build-${RUNTIME} AS build
COPY . .
ARG BUNDLE_SILENCE_ROOT_WARNING=1
RUN bundle install --path vendor/bundle/ --without development
RUN zip -r lambda.zip Gemfile* lambda.rb vendor

FROM hashicorp/terraform:${TERRAFORM} AS plan
WORKDIR /var/task/
COPY --from=build /var/task/ .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
ARG TF_VAR_destinations
ARG TF_VAR_release
RUN terraform fmt -check
RUN terraform init
RUN terraform plan -out terraform.zip
CMD ["apply", "terraform.zip"]
