FROM nginx:alpine

RUN apk add --no-cache curl \
    && curl -L -o /tmp/app.tar.gz \
       https://raw.githubusercontent.com/Ashutoshdocs/lectureDocker/main/DockerfileLearning/add-demo/app.tar.gz \
    && tar -xzf /tmp/app.tar.gz -C /usr/share/nginx/html/ \
    && rm /tmp/app.tar.gz