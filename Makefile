.PHONY: base

base:
	docker build --pull --rm --no-cache -f Dockerfile_base -t lukaszimmermann/clinical-reporting-base:latest .

reporting:
	docker build --pull --rm --no-cache -f Dockerfile_reporting -t lukaszimmermann/clinical-reporting:latest .


