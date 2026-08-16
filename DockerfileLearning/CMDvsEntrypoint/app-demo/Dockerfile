# ============================================================
# APP DEMO - a realistic, production-style image
# ------------------------------------------------------------
# The recommended pattern:
#   exec-form ENTRYPOINT  + exec-form CMD
#
# ENTRYPOINT locks the app in so the image always "is" our app.
# CMD gives sensible DEFAULT arguments the user can override
# without having to know the app is written in Python.
#
# Build (from THIS app-demo/ folder):
#   docker build -t demo:app .
#
# Run:
#   docker run --rm demo:app                 # uses CMD defaults
#   docker run --rm demo:app your own words  # overrides CMD args
# ============================================================
FROM python:3.12-slim

# Good hygiene: stream logs immediately instead of buffering.
ENV PYTHONUNBUFFERED=1

WORKDIR /app
COPY app.py .

# A default env value app.py falls back to when given no args.
ENV GREET_NAME=Docker

# Always run our app...
ENTRYPOINT ["python", "app.py"]

# ...with these default arguments (override by appending your own).
CMD ["Hello", "from", "CMD", "defaults"]
