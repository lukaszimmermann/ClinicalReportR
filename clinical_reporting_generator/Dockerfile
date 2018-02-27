FROM openjdk:alpine
MAINTAINER Lukas Zimmermann <lukas.zimmermann@uni-tuebingen.de>

ENTRYPOINT ["/usr/bin/java", "-jar", "/usr/share/generator/generator.jar"]

# Add the service itself
ARG JAR_FILE
ADD target/${JAR_FILE} /usr/share/generator/generator.jar
