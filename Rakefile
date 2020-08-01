require "rake/clean"
CLOBBER.include ".terraform"
CLEAN.include "terraform.zip", "package.iid", "package.zip"
task :default => %i[terraform:plan]

REPO    = "brutalismbot/mail"
RUNTIME = "ruby2.7"

namespace :docker do
  file "package.iid" => %i[Gemfile Gemfile.lock lambda.rb] do |f|
    sh "docker build --build-arg RUNTIME=#{RUNTIME} --iidfile #{f.name} --tag #{REPO} ."
  end

  desc "Build Docker image for package"
  task :build => %i[package.iid]

  desc "Remove Docker image"
  task :clean do
    sh "docker image ls --quiet #{REPO} | uniq | xargs docker image rm --force"
  end
end

namespace :package do
  directory "vendor" => %[package.iid] do
    sh "docker run --rm --entrypoint tar $(cat package.iid) -c #{f.name} | tar -x"
  end

  file "package.zip" => %i[vendor] do |f|
    sh "zip -9r #{f.name} Gemfile* lambda.rb vendor"
  end

  desc "Build Lambda package"
  task :build => %i[package.zip]
end

namespace :terraform do
  directory ".terraform" do
    sh "terraform init"
  end

  desc "Run terraform init"
  task :init => %i[.terraform]

  file "terraform.zip" => %i[package.zip terraform.tf], order_only: %i[.terraform] do
    sh "terraform plan -out terraform.zip"
  end

  desc "Run terraform apply"
  task :apply => %i[terraform.zip] do
    sh "terraform apply terraform.zip"
    rm "terraform.zip"
  end

  desc "Run terraform plan"
  task :plan => %i[terraform.zip]
end
