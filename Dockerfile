FROM python:3.11-slim

WORKDIR /app

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    unzip \
    make \
    && rm -rf /var/lib/apt/lists/*

# Python deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Project files — only what the pipeline needs
COPY Makefile .
COPY event_stream.csv.zip .

# dbt project — models and config only, no generated artifacts
COPY dbt_project/dbt_project.yml ./dbt_project/
COPY dbt_project/profiles.yml    ./dbt_project/
COPY dbt_project/packages.yml    ./dbt_project/
COPY dbt_project/models/         ./dbt_project/models/
COPY dbt_project/tests/          ./dbt_project/tests/

# Install dbt packages (gitignored, not in build context)
RUN dbt deps --profiles-dir dbt_project --project-dir dbt_project

# dashboard/ is a volume mount — output HTML appears on the host after the run
# Expected: -v $(pwd)/dashboard:/app/dashboard

CMD ["make", "all"]
