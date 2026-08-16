FROM ubuntu:24.04

CMD ["echo", "Hello from CMD"]


#docker build -f Dockerfile.cmd -t demo:cmd .
#docker run --rm demo:cmd
#docker run --rm demo:cmd echo "Hello from Docker run"
