.PHONY: base

base:
	docker build --pull --rm --no-cache -f Dockerfile_base -t clinical-reporting-base:latest .

reporting:
	docker build --rm --no-cache -f Dockerfile_reporting -t clinical-reporting:latest .

