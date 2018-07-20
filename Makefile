.PHONY: base

base:
	docker build --pull --rm --no-cache -f Dockerfile_base -t lukaszimmermann/clinical-reporting-base .
