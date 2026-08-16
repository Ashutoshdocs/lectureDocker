FROM mysql:8.4

LABEL maintainer="Ashutosh"
LABEL project="MySQL Docker Demo"
LABEL version="1.0"
LABEL environment="training"
LABEL description="MySQL container with runtime password"

COPY init.sql /docker-entrypoint-initdb.d/

EXPOSE 3306

