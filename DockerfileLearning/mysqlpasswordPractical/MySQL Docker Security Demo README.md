# MySQL Docker Security Demo

This practical demonstrates **three different approaches to handling a MySQL root password in Docker**:

1. ❌ Password supplied during `docker build`
2. ⚠️ Password supplied during `docker run`
3. ✅ Password supplied using Docker Compose secrets

The main objective is to understand **why secrets should not be baked into Docker images**.

---

# 1. Directory Structure

```text
mysql-docker-security-demo/
│
├── README.md
│
├── mysql-demo/
│   ├── Dockerfile
│   ├── Dockerfile.bad
│   └── init.sql
│
└── mysql-secure-demo/
    ├── compose.yaml
    └── secrets/
        └── mysql_root_password.txt
```

---

# 2. BAD APPROACH — Password During Image Build

Go to the demo directory:

```powershell
cd mysql-docker-security-demo\mysql-demo
```

The `Dockerfile.bad` contains:

```dockerfile
FROM mysql:8.4

LABEL maintainer="Ashutosh"
LABEL purpose="Docker MySQL Security Demo"
LABEL demo="DO NOT USE THIS FOR REAL SECRETS"

ARG MYSQL_ROOT_PASSWORD

RUN echo "MySQL password received during build"

ENV MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}

COPY init.sql /docker-entrypoint-initdb.d/

EXPOSE 3306
```

Build the image:

```powershell
docker build   -f Dockerfile.bad  --build-arg MYSQL_ROOT_PASSWORD=MySecret123 -t mysql-demo:bad .
```

The password has now been supplied during:

```text
docker build
```

## Why is this a problem?

The password is being handled as a build argument:

```dockerfile
ARG MYSQL_ROOT_PASSWORD
```

and then placed into an environment variable:

```dockerfile
ENV MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
```

This is not a secure way to manage secrets.

Check image history:

```powershell
docker history mysql-demo:bad
```

Inspect the image:

```powershell
docker image inspect mysql-demo:bad
```

### Teaching point

```text
Password
   ↓
docker build
   ↓
Docker image
```

You generally **do not want credentials embedded in a reusable image**.

---

# 3. Better Approach — Password at Runtime

Now use the normal `Dockerfile`.

```dockerfile
FROM mysql:8.4

LABEL maintainer="Ashutosh"
LABEL project="MySQL Docker Demo"
LABEL version="1.0"
LABEL environment="training"
LABEL description="MySQL container with runtime password"

COPY init.sql /docker-entrypoint-initdb.d/

EXPOSE 3306
```

Notice that there is **no password** in the Dockerfile.

Build the image:

```powershell
docker build `
  -t mysql-demo:1.0 `
  -f Dockerfile .
```

The resulting image is generic:

```text
mysql-demo:1.0
```

---

# 4. Start MySQL Container

Supply the password when creating the container:

```powershell
docker run -d `
  --name mysql01 `
  -e MYSQL_ROOT_PASSWORD=MySecret123 `
  -p 3306:3306 `
  mysql-demo:1.0
```

Check the container:

```powershell
docker ps
```

Expected:

```text
mysql01
```

---

# 5. Check MySQL Logs

Run:

```powershell
docker logs mysql01
```

Wait until MySQL has completed initialization and is ready to accept connections.

---

# 6. Connect to MySQL

Run:

```powershell
docker exec -it mysql01 mysql -uroot -p
```

When prompted:

```text
Enter password:
```

Enter:

```text
MySecret123
```

---

# 7. Check Databases

Inside MySQL:

```sql
SHOW DATABASES;
```

You should see the default MySQL databases and:

```text
trainingdb
```

The `init.sql` file creates this database automatically when the MySQL data directory is initialized for the first time.

---

# 8. Check the Training Database

Run:

```sql
USE trainingdb;
```

Check tables:

```sql
SHOW TABLES;
```

You should see:

```text
students
```

Check the data:

```sql
SELECT * FROM students;
```

Expected data:

```text
Student01
Student02
Student03
```

---

# 9. Understanding `init.sql`

The file contains:

```sql
CREATE DATABASE IF NOT EXISTS trainingdb;

USE trainingdb;

CREATE TABLE IF NOT EXISTS students (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    course VARCHAR(100)
);

INSERT INTO students (name, course)
VALUES
    ('Student01', 'Docker'),
    ('Student02', 'Kubernetes'),
    ('Student03', 'Azure');
```

The MySQL official image processes initialization scripts placed under:

```text
/docker-entrypoint-initdb.d/
```

The Dockerfile copies the script:

```dockerfile
COPY init.sql /docker-entrypoint-initdb.d/
```

---

# 10. Important Behavior of `init.sql`

Initialization scripts normally run when the MySQL data directory is initialized.

If the container is restarted:

```powershell
docker restart mysql01
```

the database is not recreated from scratch.

If you remove the container but keep its data volume, the initialization script will not necessarily run again.

For a clean demonstration, remove the container and associated data appropriately before starting again.

---

# 11. Environment Variable Approach

Instead of putting the password directly into the command:

```powershell
docker run -d `
  --name mysql01 `
  -e MYSQL_ROOT_PASSWORD=MySecret123 `
  mysql-demo:1.0
```

PowerShell can store it in an environment variable:

```powershell
$env:MYSQL_ROOT_PASSWORD = "MySecret123"
```

Then:

```powershell
docker run -d `
  --name mysql01 `
  -e MYSQL_ROOT_PASSWORD `
  -p 3306:3306 `
  mysql-demo:1.0
```

This avoids putting the literal password in that particular command.

However, environment variables are **not a complete production secret-management solution**.

---

# 12. Docker Compose Secrets

For a stronger demonstration, use Docker Compose secrets.

Go to:

```powershell
cd ..\mysql-secure-demo
```

Directory:

```text
mysql-secure-demo/
│
├── compose.yaml
│
└── secrets/
    └── mysql_root_password.txt
```

The password file contains:

```text
MySecret123
```

---

# 13. `compose.yaml`

The Compose configuration uses:

```yaml
services:

  mysql:
    image: mysql:8.4

    container_name: mysql01

    environment:
      MYSQL_ROOT_PASSWORD_FILE: /run/secrets/mysql_root_password

    ports:
      - "3306:3306"

    volumes:
      - mysql_data:/var/lib/mysql

    secrets:
      - mysql_root_password

secrets:

  mysql_root_password:
    file: ./secrets/mysql_root_password.txt

volumes:

  mysql_data:
```

The important part is:

```yaml
MYSQL_ROOT_PASSWORD_FILE: /run/secrets/mysql_root_password
```

The password is made available through a secret rather than being written directly into the image.

---

# 14. Start the Compose Application

Run:

```powershell
docker compose up -d
```

Check:

```powershell
docker compose ps
```

Check logs:

```powershell
docker compose logs mysql
```

---

# 15. Connect to MySQL

Run:

```powershell
docker exec -it mysql01 mysql -uroot -p
```

Enter:

```text
MySecret123
```

Then:

```sql
SHOW DATABASES;
```

---

# 16. Understand the Secret Flow

The Compose approach works conceptually like this:

```text
mysql_root_password.txt
          │
          ▼
     Docker Secret
          │
          ▼
 /run/secrets/mysql_root_password
          │
          ▼
      MySQL Container
```

The image itself does not contain the password.

---

# 17. Image vs Container

This is one of the most important concepts in the demo.

## Image

```text
mysql-demo:1.0
```

Contains:

```text
MySQL software
Configuration
Initialization script
Labels
```

It should be reusable.

## Container

```text
mysql01
```

Contains the running MySQL instance and its runtime configuration.

Conceptually:

```text
             IMAGE
       ┌───────────────┐
       │ MySQL          │
       │ Configuration  │
       │ init.sql       │
       └───────┬───────┘
               │
          docker run
               │
               ▼
       ┌───────────────┐
       │   CONTAINER   │
       │               │
       │ Password      │
       │ Database      │
       │ Data          │
       └───────────────┘
```

---

# 18. Security Comparison

## ❌ Bad

```text
Dockerfile
    │
    ├── ARG MYSQL_ROOT_PASSWORD
    │
    └── ENV MYSQL_ROOT_PASSWORD
             │
             ▼
          IMAGE
```

The secret is being associated with the image/build.

---

## ⚠️ Better for a Simple Lab

```text
docker run
    │
    └── MYSQL_ROOT_PASSWORD
             │
             ▼
         CONTAINER
```

The password is not baked into the Dockerfile.

Still, environment variables should not be treated as a comprehensive production secret-management system.

---

## ✅ Better Secret Pattern

```text
Secret
   │
   ▼
/run/secrets/mysql_root_password
   │
   ▼
MySQL Container
```

The image remains generic.

---

# 19. Why Not Put Password in `Dockerfile`?

Never do this:

```dockerfile
FROM mysql:8.4

ENV MYSQL_ROOT_PASSWORD=MySecret123
```

Also avoid:

```dockerfile
ARG MYSQL_ROOT_PASSWORD=MySecret123

ENV MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
```

Why?

Because Docker images are designed to be:

```text
Built
↓
Tagged
↓
Stored
↓
Shared
↓
Pushed to Registry
↓
Pulled by Other Machines
```

You do not want your database password traveling with the image.

---

# 20. Cleanup — Manual Docker Run

If you created the container manually:

```powershell
docker rm -f mysql01
```

Remove the image:

```powershell
docker rmi mysql-demo:1.0
```

Remove the bad image:

```powershell
docker rmi mysql-demo:bad
```

---

# 21. Cleanup — Docker Compose

From:

```text
mysql-secure-demo
```

run:

```powershell
docker compose down
```

To also remove the named volume:

```powershell
docker compose down -v
```

**Warning:** removing the volume removes the stored MySQL data associated with that Compose volume.

---

# 22. Complete Practical Sequence

## Demo 1 — Bad

```powershell
cd mysql-docker-security-demo\mysql-demo

docker build `
  -f Dockerfile.bad `
  --build-arg MYSQL_ROOT_PASSWORD=MySecret123 `
  -t mysql-demo:bad .

docker history mysql-demo:bad

docker image inspect mysql-demo:bad
```

Explain why this is a security concern.

---

## Demo 2 — Runtime Password

```powershell
docker build `
  -t mysql-demo:1.0 `
  -f Dockerfile .

docker run -d `
  --name mysql01 `
  -e MYSQL_ROOT_PASSWORD=MySecret123 `
  -p 3306:3306 `
  mysql-demo:1.0

docker ps

docker logs mysql01

docker exec -it mysql01 mysql -uroot -p
```

---

## Demo 3 — Compose Secret

```powershell
cd ..\mysql-secure-demo

docker compose up -d

docker compose ps

docker compose logs mysql

docker exec -it mysql01 mysql -uroot -p
```

---

# 23. Key Dockerfile Instructions

| Instruction | Purpose |
|---|---|
| `FROM` | Selects the base image |
| `LABEL` | Adds image metadata |
| `ARG` | Defines a build-time variable |
| `ENV` | Defines an environment variable |
| `COPY` | Copies files into the image |
| `RUN` | Executes commands during image build |
| `EXPOSE` | Documents the intended container port |

---

# 24. Key MySQL Docker Variables

### `MYSQL_ROOT_PASSWORD`

Used to initialize the MySQL root password.

Example:

```powershell
docker run -e MYSQL_ROOT_PASSWORD=MySecret123 mysql:8.4
```

### `MYSQL_ROOT_PASSWORD_FILE`

Allows the MySQL image to read the root password from a file.

Example:

```yaml
environment:
  MYSQL_ROOT_PASSWORD_FILE: /run/secrets/mysql_root_password
```

This is useful when using Docker secrets.

---

# 25. Final Mental Model

```text
                 Dockerfile
                     │
                     ▼
               docker build
                     │
                     ▼
                Docker Image
                     │
          ┌──────────┴──────────┐
          │                     │
       LABEL                   COPY
          │                     │
       Metadata              init.sql
          │                     │
          └──────────┬──────────┘
                     │
                     ▼
                docker run
                     │
              Runtime Secret
                     │
                     ▼
                MySQL Container
                     │
                     ▼
                 MySQL DB
```

---

# 26. Final Teaching Point

Remember:

```text
ARG
→ Build-time variable

ENV
→ Runtime environment variable

LABEL
→ Image metadata

RUN
→ Execute during image build

COPY
→ Copy files into image

EXPOSE
→ Document container port

MYSQL_ROOT_PASSWORD
→ Runtime MySQL initialization configuration

MYSQL_ROOT_PASSWORD_FILE
→ Read MySQL password from a mounted secret
```

## Golden Rule

> **Build the image without the password. Supply the password separately at runtime, preferably through a proper secret-management mechanism.**

For a production environment, use a dedicated secret-management solution such as Docker/Swarm secrets, Kubernetes Secrets with appropriate protections, or a cloud secret manager rather than hard-coding credentials in Dockerfiles.
