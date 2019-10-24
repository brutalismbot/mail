runtime   := ruby2.5
stages    := build plan
terraform := latest
build     := $(shell git describe --tags --always)
shells    := $(foreach stage,$(stages),shell@$(stage))

.PHONY: all apply clean $(stages) $(shells)

all: Gemfile.lock lambda.zip plan

.docker:
	mkdir -p $@

.docker/$(build)@plan: .docker/$(build)@build
.docker/$(build)@%: | .docker
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg RUNTIME=$(runtime) \
	--build-arg TERRAFORM=$(terraform) \
	--build-arg TF_VAR_destinations \
	--build-arg TF_VAR_release=$(build) \
	--iidfile $@ \
	--tag brutalismbot/mail:$(build)-$* \
	--target $* .

Gemfile.lock lambda.zip: .docker/$(build)@build
	docker run --rm \
	--entrypoint cat \
	$(shell cat $<) \
	$@ > $@

apply: .docker/$(build)@plan
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	$(shell cat $<)

clean:
	-docker image rm -f $(shell awk {print} .docker/*)
	-rm -rf .docker *.zip

$(stages): %: .docker/$(build)@%

$(shells): shell@%: .docker/$(build)@% .env
	docker run --rm -it \
	--entrypoint /bin/sh \
	--env-file .env \
	$(shell cat $<)
