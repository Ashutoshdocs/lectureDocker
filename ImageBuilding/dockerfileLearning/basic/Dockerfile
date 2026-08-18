# Base image
FROM alpine:latest

# Image metadata
LABEL maintainer="Ashutosh"
LABEL description="Basic Dockerfile Demo"
LABEL version="1.0"

# Environment variable
ENV APP_NAME="DockerDemo"
ENV APP_ENV="production"

# Working directory
WORKDIR /app

# Execute commands while building the image
RUN apk add --no-cache curl
RUN echo "Hello Docker" > hello.txt
RUN mkdir logs

#docker build -t basic-demo:v1 .
