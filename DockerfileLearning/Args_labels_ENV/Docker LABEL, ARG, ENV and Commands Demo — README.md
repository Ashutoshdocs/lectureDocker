# Docker LABEL, ARG, ENV and Commands Demo

This practical demonstrates how Docker `LABEL`, `ARG`, `ENV`, `WORKDIR`, `COPY`, `RUN`, and `CMD` work together.

---

## 4. Build the Image

Build the image using the default values defined in the Dockerfile:

```bash
docker build -t docker-demo:1.0 .
```

During the build, you should see:

```text
Building application: DockerDemo
Application version: 1.0
Build performed by: Trainer
```

---

## 5. Override ARG During Build

`ARG` values can be overridden using `--build-arg`.

```bash
docker build \
  --build-arg APP_NAME=StudentApp \
  --build-arg APP_VERSION=2.0 \
  --build-arg BUILD_BY=Student \
  -t docker-demo:2.0 .
```

During the build, you should see:

```text
Building application: StudentApp
Application version: 2.0
Build performed by: Student
```

### Important Concept

```text
ARG
 │
 └── Available during IMAGE BUILD
```

For example:

```dockerfile
ARG APP_VERSION=1.0
```

Override it with:

```bash
docker build --build-arg APP_VERSION=2.0 -t docker-demo:2.0 .
```

---

## 6. Check Image Labels

The Dockerfile contains multiple labels:

```dockerfile
LABEL maintainer="Ashutosh"
LABEL project="Docker Teaching Demo"
LABEL version="1.0"
LABEL environment="training"
LABEL description="Demo of Docker LABEL, ARG and commands"
```

Inspect the image:

```bash
docker image inspect docker-demo:1.0
```

A cleaner command is:

```bash
docker image inspect docker-demo:1.0 \
  --format '{{json .Config.Labels}}'
```

Example output:

```text
{
  "maintainer": "Ashutosh",
  "project": "Docker Teaching Demo",
  "version": "1.0",
  "environment": "training",
  "description": "Demo of Docker LABEL, ARG and commands"
}
```

### Check an Individual Label

Check the maintainer:

```bash
docker image inspect docker-demo:1.0 \
  --format '{{index .Config.Labels "maintainer"}}'
```

Output:

```text
Ashutosh
```

Check the version:

```bash
docker image inspect docker-demo:1.0 \
  --format '{{index .Config.Labels "version"}}'
```

Output:

```text
1.0
```

---

## 7. Run the Container

Run the image:

```bash
docker run --rm docker-demo:1.0
```

Expected output:

```text
Application: DockerDemo
Version: 1.0
Hello from Docker LABEL + ARG demo!
```

The `CMD` instruction is responsible for the default command:

```dockerfile
CMD ["sh", "-c", "echo Application: $APP_NAME; echo Version: $APP_VERSION; cat /app/app.txt"]
```

---

## 8. Prove That ARG and ENV Are Different

Build an image with custom `ARG` values:

```bash
docker build \
  --build-arg APP_NAME=StudentApp \
  --build-arg APP_VERSION=5.0 \
  -t docker-demo:5.0 .
```

Run it:

```bash
docker run --rm docker-demo:5.0
```

Expected output:

```text
Application: StudentApp
Version: 5.0
Hello from Docker LABEL + ARG demo!
```

Why does this work?

The Dockerfile converts the build-time `ARG` into an `ENV` variable:

```dockerfile
ARG APP_NAME="DockerDemo"
ARG APP_VERSION="1.0"

ENV APP_NAME=${APP_NAME}
ENV APP_VERSION=${APP_VERSION}
```

Conceptually:

```text
                    docker build
                         |
                         v
                    ARG APP_NAME
                         |
                         v
                    ENV APP_NAME
                         |
                         v
                  Running Container
```

---

## 9. Show Environment Variables Inside the Container

Run:

```bash
docker run --rm docker-demo:5.0 env
```

Look for:

```text
APP_NAME=StudentApp
APP_VERSION=5.0
```

You can also check a specific variable:

```bash
docker run --rm docker-demo:5.0 \
  sh -c 'echo $APP_NAME'
```

Expected output:

```text
StudentApp
```

Check the version:

```bash
docker run --rm docker-demo:5.0 \
  sh -c 'echo $APP_VERSION'
```

Expected output:

```text
5.0
```

---

## 10. Important Demo: ARG Is Build-Time

Add the following to the Dockerfile:

```dockerfile
ARG SECRET="12345"

RUN echo "Secret during build = ${SECRET}"
```

Build the image:

```bash
docker build \
  --build-arg SECRET=99999 \
  -t secret-demo .
```

The value can be used during the build:

```text
Secret during build = 99999
```

However, the `ARG` itself does not automatically become a runtime environment variable.

Run:

```bash
docker run --rm secret-demo \
  sh -c 'echo $SECRET'
```

The `SECRET` variable will not automatically contain the build argument value.

### Concept

```text
ARG
 |
 +---- docker build
 |
 +---- Build-time only
```

Whereas:

```text
ENV
 |
 +---- Image
 |
 +---- Running container
 |
 +---- Runtime environment
```

### Security Warning

Do not use `ARG` as a secure mechanism for passwords, API keys, tokens, or other secrets.

Build arguments may become visible through build history or other image/build metadata depending on how they are used.

Use proper Docker/BuildKit secret mechanisms for sensitive build-time credentials.

---

## 11. Show Docker Image History

Docker creates image layers from many Dockerfile instructions.

Check the history:

```bash
docker history docker-demo:1.0
```

You should see commands corresponding to instructions such as:

```text
RUN
WORKDIR
COPY
RUN
```

Conceptually:

```text
Dockerfile
    |
    v
docker build
    |
    v
Image Layers
    |
    v
docker history
```

This is useful for understanding how Docker builds an image.

---

## 12. Complete Demo Flow

### Step 1 — Build

```bash
docker build -t docker-demo:1.0 .
```

### Step 2 — Run

```bash
docker run --rm docker-demo:1.0
```

### Step 3 — Build With Custom Arguments

```bash
docker build \
  --build-arg APP_NAME=MyApplication \
  --build-arg APP_VERSION=10.0 \
  --build-arg BUILD_BY=Ashutosh \
  -t myapp:10.0 .
```

### Step 4 — Inspect Labels

```bash
docker image inspect myapp:10.0 \
  --format '{{json .Config.Labels}}'
```

### Step 5 — Run Custom Image

```bash
docker run --rm myapp:10.0
```

### Step 6 — Check Environment

```bash
docker run --rm myapp:10.0 env
```

### Step 7 — Check Image History

```bash
docker history myapp:10.0
```

---

# 13. Dockerfile Instruction Summary

| Instruction | Purpose | Main Stage |
|---|---|---|
| `FROM` | Selects the base image | Build |
| `LABEL` | Adds metadata to an image | Image metadata |
| `ARG` | Defines build-time variables | Build |
| `ENV` | Defines environment variables | Runtime |
| `WORKDIR` | Sets the working directory | Build/Runtime |
| `COPY` | Copies files into the image | Build |
| `RUN` | Executes commands during image build | Build |
| `CMD` | Defines the default container command | Runtime |

---

# 14. Easy Teaching Explanation

## LABEL

Think:

```text
LABEL = Information ABOUT the image
```

Example:

```dockerfile
LABEL project="Docker Teaching Demo"
```

Used for image metadata.

---

## ARG

Think:

```text
ARG = Information USED while BUILDING the image
```

Example:

```dockerfile
ARG APP_VERSION=1.0
```

Override:

```bash
docker build --build-arg APP_VERSION=2.0 .
```

---

## ENV

Think:

```text
ENV = Information AVAILABLE inside the running container
```

Example:

```dockerfile
ENV APP_VERSION=1.0
```

Check:

```bash
docker run --rm image-name env
```

---

## RUN

Think:

```text
RUN = DO THIS NOW while BUILDING the image
```

Example:

```dockerfile
RUN apt-get update
```

It executes during:

```bash
docker build
```

---

## COPY

Think:

```text
COPY = Take files from my computer
       and put them inside the image
```

Example:

```dockerfile
COPY app.txt /app/
```

---

## WORKDIR

Think:

```text
WORKDIR = Where should commands/files operate?
```

Example:

```dockerfile
WORKDIR /app
```

---

## CMD

Think:

```text
CMD = What should the container do BY DEFAULT?
```

Example:

```dockerfile
CMD ["echo", "Hello"]
```

It executes when:

```bash
docker run image-name
```

---

# 15. Final Mental Model

```text
                 Dockerfile
                     |
        +------------+-------------+
        |            |             |
       LABEL         ARG           RUN
        |            |             |
     Metadata     Build-time     Build command
                     |
                     v
                    ENV
                     |
                     v
                  IMAGE
                     |
              +------+------+
              |             |
            COPY          WORKDIR
              |             |
              +------+------+
                     |
                     v
                docker run
                     |
                     v
                    CMD
                     |
                     v
                CONTAINER
```

### Remember

```text
LABEL → Metadata

ARG   → Build-time variable

ENV   → Runtime environment variable

RUN   → Execute during build

COPY  → Copy files into image

WORKDIR → Set working directory

CMD   → Default command at container startup
```

---

# 16. One-Line Demo for Students

Build:

```bash
docker build --build-arg APP_NAME=MyApplication --build-arg APP_VERSION=10.0 --build-arg BUILD_BY=Ashutosh -t myapp:10.0 .
```

Inspect:

```bash
docker image inspect myapp:10.0 --format '{{json .Config.Labels}}'
```

Run:

```bash
docker run --rm myapp:10.0
```

Check environment:

```bash
docker run --rm myapp:10.0 env
```

Check layers:

```bash
docker history myapp:10.0
```

This sequence demonstrates the complete flow:

```text
ARG
 ↓
docker build
 ↓
IMAGE
 ↓
LABEL / ENV / COPY / RUN
 ↓
docker run
 ↓
CMD
 ↓
CONTAINER
```