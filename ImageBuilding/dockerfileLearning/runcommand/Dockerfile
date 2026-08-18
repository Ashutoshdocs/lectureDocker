FROM python:3.12-alpine

WORKDIR /app

# RUN #1: Download something from the internet
RUN apk add --no-cache curl \
    && curl -L -o /tmp/sample.txt https://raw.githubusercontent.com/docker-library/official-images/master/README.md

# Copy requirements.txt into the image
COPY requirements.txt .

# RUN #2: Install dependencies from requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

CMD ["python", "--version"]
