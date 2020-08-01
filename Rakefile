require "rake/clean"
CLOBBER.include ".terraform"
CLEAN.include ".terraform/terraform.zip", "package.iid", "package.zip"
task :default => %i[terraform:plan]

REPO    = "brutalismbot/mail"
RUNTIME = "ruby2.7"

namespace :package do
  directory "vendor" => %[package.iid] do
    sh "docker run --rm --entrypoint tar $(cat package.iid) -c #{f.name} | tar -x"
  end

  file "package.iid" => %i[Gemfile Gemfile.lock lambda.rb] do |f|
    sh "docker build --build-arg RUNTIME=#{RUNTIME} --iidfile #{f.name} --tag #{REPO} ."
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

  file ".terraform/terraform.zip" => %i[package.zip terraform.tf], order_only: %i[.terraform] do
    sh "terraform plan -out .terraform/terraform.zip"
  end

  desc "Run terraform apply"
  task :apply => %i[.terraform/terraform.zip] do
    sh "terraform apply .terraform/terraform.zip"
  end

  desc "Run terraform plan"
  task :plan => %i[.terraform/terraform.zip]
end
