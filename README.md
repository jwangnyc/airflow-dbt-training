

# Required system setup
## git

```
brew install git
```

Follow git steps to complete setup.

## Python
If you don't have Python installed, use the following to install Python. Version 3.11 is recomended.
```
brew install python@3.11
```


# Clone training repo

```
cd ~  # go to your home dir
mkdir work # create a working dir for all of your code
cd work
git clone git@github.com:jwangnyc/airflow-dbt-training.git
```

## Setup local development env

### Create virtual Python environment for you Airflow/dbt

```
cd ~/work/airflow-dbt-training

python3.11 -m venv .venv
source .venv/bin/activate
pip install dbt-core==1.8
pip install dbt-duckdb==1.9
pip install dbt-snowflake
pip install dbt-adapters

sh airflow-install.sh

```
Start Airflow

```
airflow db init

airflow users create \
    --username admin \
    --firstname <your firstname> \
    --lastname <your lastname> \
    --role Admin \
    --email <your email>

# open a new terminal to run the following commands
airflow webserver --port 8080
airflow scheduler
```

# dbt commands

```
dbt debug
dbt build --profiles-dir ./  
dbt run --profiles-dir ./  
dbt docs generate
dbt docs serve --profiles-dir ./  

```