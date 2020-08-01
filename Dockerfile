ARG RUNTIME=ruby2.7
FROM lambci/lambda:build-${RUNTIME}
RUN bundle config --local path vendor/bundle/
RUN bundle config --local silence_root_warning 1
RUN bundle config --local without development
COPY . .
RUN bundle
