SHELL:=/bin/bash -O globstar
.SHELLFLAGS = -ec
.PHONY: build dist
.DEFAULT_GOAL := list

list:
	@grep '^[^#[:space:]].*:' Makefile

guard-%:
	@ if [ "${${*}}" = "" ]; then \
		echo "Environment variable $* not set"; \
		exit 1; \
	fi

pwd := ${PWD}
dirname := $(notdir $(patsubst %/,%,$(CURDIR)))

#the LC_COLLATE on the line below is since the default sort (on my machine) is en_GB.UTF-8. Specifying 
#LC_COLLATE=C for the sort command sorts in ASCII, so underscores (lambda base layers) go before alphabetical.
lambdas := $(shell find . -maxdepth 1 -mindepth 1 -type d -not -path ./dist -not -path ./_shared -not -path ./.mypy_cache  | sed 's\./\\' | LC_COLLATE=C sort)

clean:
	@rm -rf ./dist || true
	@for dir in $(lambdas); do \
  		echo $$dir; \
		make --no-print-directory -C $$dir clean; \
	done;

dist: clean
	@mkdir -p ./dist
	@for dir in $(lambdas); do \
  		echo $$dir; \
		make -C $$dir dist; \
	done;
	wait;

dist-localstack: clean
	@mkdir -p ./dist
	@for dir in $(lambdas); do \
  		echo $$dir; \
		make -C $$dir dist-localstack; \
		cp $$dir/dist/*.zip ./dist; \
	done;
	wait;

install:
	@mkdir -p ./dist
	@for dir in $(lambdas); do \
  		echo $$dir; \
		make --no-print-directory -C $$dir install; \
	done;
	wait;

purge:
	@for dir in $(lambdas); do \
  		echo $$dir; \
		make --no-print-directory -C $$dir purge; \
	done;
	rm -rf .mypy_cache || true
	rm -rf dist || true
	wait;

reinstall:
	@for dir in $(lambdas); do \
  		echo $$dir; \
		make --no-print-directory -C $$dir reinstall; \
	done;
	wait;

test:
	@for dir in $(lambdas); do \
  		echo $$dir; \
		make --no-print-directory -C $$dir test; \
	done;
	wait;

scan:
	@for dir in $(lambdas); do \
  		echo $$dir; \
		make --no-print-directory -C $$dir scan; \
	done;
	wait;

echo:
	@for dir in $(lambdas); do \
  		echo $$dir; \
  		make --no-print-directory -C $$dir echo; \
	done;
	wait;


mypy:
	@for dir in $(lambdas); do \
  		echo $$dir; \
  		make --no-print-directory -C $$dir mypy; \
	done;
	wait;

safety:
	for dir in $(lambdas); do \
  		echo $$dir; \
		make --no-print-directory -C  $$dir safety safety_action="$$safety_action" workspace="../.." detail="[lambda]$$dir" publish_artifacts="$$publish_artifacts"; \
	done;
	wait;