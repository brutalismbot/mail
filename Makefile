name    := mail
runtime := ruby2.5
build   := $(shell git describe --tags --always)
digest   = $(shell cat .docker/$(build)$(1))

.PHONY: all apply clean shell

all: Gemfile.lock lambda.zip

.docker:
	mkdir -p $@

.docker/$(build)@plan: .docker/$(build)@build
.docker/$(build)@%: | .docker
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg RUNTIME=$(runtime) \
	--build-arg TF_VAR_release=$(build) \
	--iidfile $@ \
	--tag brutalismbot/$(name):$(build)-$* \
	--target $* .

Gemfile.lock lambda.zip: .docker/$(build)@build
	docker run --rm -w /var/task/ $(call digest,@build) cat $@ > $@

apply: plan
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	$(call digest,@plan)

clean:
	-docker image rm -f $(shell awk {print} .docker/*)
	-rm -rf .docker *.zip

plan: all .docker/$(build)@plan

shell@%: .docker/$(build)@% .env
	docker run --rm -it --env-file .env $(call digest,@$*) /bin/bash
