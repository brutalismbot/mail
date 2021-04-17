require "dotenv/load"
require "rake/clean"
CLEAN.include ".terraform", "package.zip"
task :default => %i[terraform:plan]
task :clean   => %i[docker:clean]

namespace :docker do
  @repo = "brutalismbot/mail"

  desc "Export lib"
  task :export => :build do
    sh %{docker run --rm --entrypoint tar #{ @repo } cf - . | (cd lib && tar xf - )}
  end

  desc "Build Docker image"
  task :build do
    sh %{docker build --tag #{ @repo } .}
  end

  desc "Remove Docker image"
  task :clean do
    sh "docker image ls --quiet #{ @repo } | uniq | xargs docker image rm --force"
  end
end

namespace :package do
  @files = Dir["lib/*"] - Dir["lib/*.zip"]

  file "package.zip" => @files do |f|
    sh %{cd lib && zip -9r ../package.zip .}
  end

  desc "Build Lambda package"
  task :zip => %i[package.zip]
end

namespace :terraform do
  %i[plan apply].each do |cmd|
    desc "Run terraform #{ cmd }"
    task cmd => %i[init package:zip] do
      sh %{terraform #{ cmd }}
    end
  end

  namespace :apply do
    desc "Run terraform auto -auto-approve"
    task :auto => %i[init package:zip] do
      sh %{terraform apply -auto-approve}
    end
  end

  task :init => ".terraform"

  directory ".terraform" do
    sh %{terraform init}
  end
end
