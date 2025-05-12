airflow db init

airflow users create \
    --username admin \
    --firstname Jerry \
    --lastname Wang \
    --role Admin \
    --email jerry.wang@1stdibs.com

airflow webserver --port 8080

airflow scheduler