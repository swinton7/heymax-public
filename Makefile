.PHONY: install extract transform test dashboard all clean

install:
	pip install -r requirements.txt

extract:
	@echo "Extracting event_stream.csv.zip → data/"
	mkdir -p data
	unzip -o event_stream.csv.zip -d data/
	@echo "Extraction complete"

transform: extract
	dbt deps --profiles-dir dbt_project --project-dir dbt_project
	dbt run --profiles-dir dbt_project --project-dir dbt_project

test:
	dbt test --profiles-dir dbt_project --project-dir dbt_project

docs:
	dbt docs generate --profiles-dir dbt_project --project-dir dbt_project
	dbt docs serve --profiles-dir dbt_project --project-dir dbt_project

dashboard:
	python3 dashboard/build_notebook.py
	jupyter nbconvert --to html --execute dashboard/growth_accounting.ipynb --output-dir dashboard

all: extract transform test dashboard

clean:
	rm -f heymax.duckdb
	rm -rf data/ dbt_project/target dbt_project/logs
