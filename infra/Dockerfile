# Agent fills in this file based on specs/prd.md "Base image", "Language", and "Framework".
#
# Example (Python/FastAPI):
#   FROM python:3.12-slim
#   WORKDIR /app
#   COPY app/requirements.txt .
#   RUN pip install --no-cache-dir -r requirements.txt
#   COPY app/ .
#   CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
#
# Example (Node/Express):
#   FROM node:20-alpine
#   WORKDIR /app
#   COPY app/package*.json .
#   RUN npm ci --omit=dev
#   COPY app/ .
#   CMD ["node", "src/index.js"]

FROM [base-image]

WORKDIR /app

# Copy and install dependencies
# COPY app/[dependency-file] .
# RUN [install command]

COPY app/ .

# CMD ["your", "start", "command"]
