FROM ubuntu:24.04

# ============================================================
# LABELS
# Metadata about the image
# ============================================================

LABEL maintainer="Ashutosh"
LABEL project="Docker Teaching Demo"
LABEL version="1.0"
LABEL environment="training"
LABEL description="Demo of Docker LABEL, ARG and commands"

# ============================================================
# ARG
# Build-time variables
# ============================================================

ARG APP_NAME="DockerDemo"
ARG APP_VERSION="1.0"
ARG BUILD_BY="Trainer"

# Display ARG values during image build
RUN echo "Building application: ${APP_NAME}" && \
    echo "Application version: ${APP_VERSION}" && \
    echo "Build performed by: ${BUILD_BY}"

# ============================================================
# ENV
# Runtime environment variables
# ============================================================

ENV APP_NAME=${APP_NAME}
ENV APP_VERSION=${APP_VERSION}

# ============================================================
# WORKDIR
# ============================================================

WORKDIR /app

# ============================================================
# COPY
# ============================================================

COPY app.txt /app/

# ============================================================
# RUN
# ============================================================

RUN echo "Application files:" && \
    ls -l /app

# ============================================================
# CMD
# ============================================================

CMD ["sh", "-c", "echo Application: $APP_NAME; echo Version: $APP_VERSION; cat /app/app.txt"]