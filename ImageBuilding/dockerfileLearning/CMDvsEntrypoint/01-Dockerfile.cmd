# ============================================================
# 01 - CMD ONLY
# ------------------------------------------------------------
# CMD provides the DEFAULT command for the container.
# Whatever you type after the image name in `docker run`
# COMPLETELY REPLACES this line.
#
#   docker run img                 -> python app.py default-from-CMD
#   docker run img echo hi         -> echo hi   (app.py never runs!)
# ============================================================
FROM python:3.12-slim

WORKDIR /demo
COPY app-demo/app.py .

# Exec form (preferred). This entire line is thrown away the
# moment the user supplies their own command.
CMD ["python", "app.py", "default-from-CMD"]
