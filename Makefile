name  := mail
build := $(shell git describe --tags --always)
digest = $(shell cat .docker/$(build))

.PHONY: all apply clean shell

all: .docker/$(build)

.docker:
	mkdir -p $@

.docker/%: | .docker
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg TF_VAR_release=$* \
	--iidfile $@ \
	--tag brutalismbot/$(name):$* .

apply: .docker/$(build)
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	$(digest)

clean:
	-docker image rm -f $(shell awk {print} .docker/*)
	-rm -rf .docker

shell: .docker/$(build) .env
	docker run --rm -it --env-file .env $(digest) /bin/bash
