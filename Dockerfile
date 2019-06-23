ARG RUNTIME=ruby2.5

FROM lambci/lambda:build-${RUNTIME} AS build
COPY Gemfile* lambda.rb /var/task/
ARG BUNDLE_SILENCE_ROOT_WARNING=1
RUN bundle install --path vendor/bundle/ --without development
RUN zip -r lambda.zip Gemfile* lambda.rb vendor

FROM build AS test
COPY --from=hashicorp/terraform:0.12.2 /bin/terraform /bin/
RUN terraform fmt -check

FROM test AS plan
COPY terraform.tf .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
ARG TF_VAR_destinations
ARG TF_VAR_release
RUN terraform init
RUN terraform plan -out terraform.zip
CMD ["terraform", "apply", "terraform.zip"]
