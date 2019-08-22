# Airflow Operations - Deployment

## Prepare for deployment
### [Opt] Create virtualenv and install `ansible`
<span style="color:red">Do it if `ansible` is not installed globally, or skip this step</span>
```
./pre-deploy.sh -e ut [-f]
source venv/bin/activate
```
* `-f` will force delete the old venv and create a new one, or it will raise error if venv already exists

### Modify base path and other variables
* find `<define your path>` in `<service>/<service>-vars/<service>-<env>.yml` and modify to define your `base_path`
* check and modify other variables if needed

### Ensure that ssh key for gitlab or tfs is set
The script will download repos from github, make sure the following command works
> github (dev)
```
ssh -T git@github.com
```

## Deploy services
> env: dev
### postgresql
#### install from source code
```
./deploy.sh -s postgresql -e <env>
```
Download source code from [postgresql](https://www.postgresql.org/ftp/source/). The location of file is described in service structure below.
> build `postgresql` from source if you don't have root privilege.

> <span style="color:red">postgresql server is started after deployment.</span>
* start postgresql server manually
```
./bin/pg_ctl -D ./data/ -l logfile start
```
* stop postgresql server manually
```
./bin/pg_ctl -D ./data/ stop
```

#### [dev] install from binary
> If testing with `dev` environment, it's easier to install from binary and you need to create db, user and grant permission manually.
```postgresql
postgres=# create database <db>;
postgres=# create user <user> with encrypted password '<pwd>';
postgres=# grant all privileges on database <db> to <user>;
```
Check if `backend_db` in `airflow/airflow-vars/airflow-<env>.yml` is set to `postgresql://<user>:<pwd>@0.0.0.0:5432/<db>`

### redis
```
./deploy.sh -s redis -e <env>
```
Download from [redis](https://redis.io/download). The location of file is described in service structure below.
> <span style="color:red">redis server is started in the last step of deployment.</span>
* start redis server manually
```
src/redis-server > ../redis.log 2>&1 &
```
* stop redis server manually
```
src/redis-cli shutdown
```

### airflow
```
./deploy.sh -s airflow -e <env> [--keep_db] [--keep_venv] [--install_from_source]
```
* `--keep_db` modify `sql_alchemy_conn` in `airflow.cfg` to change backend db from *sqllite(default)* to *postgresql* without reseting db, some data such as connections, variables, and pools ... will not be deleted. <span style="color:red">Do not use this argument if backend database is already empty or `airflow.cfg` is not exist.</span>
* `--keep_venv` speeds up the deployment process without removing existed venv. However, <span style="color:red">if there're new version of libraries, don't use this argument since it may not upgrade the libraries.</span>
* `--install_from_source` clone repo from `airflow_git_repo` and build instead of trying to download from nexus. Unstall `apache-airflow` packages first and install from source again when it's used with `--keep_venv`.
<span style="color:red">* airflow deployment includes writing config file to `var/airflow-deployment-conf.sh`, it is used for scripts to read and control the services</span>

## Start airflow
> use -h to show usage function
* start from scripts, process running in backgroud
```python
# start | stop | restart | status
scripts/airflow-webserver.sh [start|stop|restart|status]
scripts/airflow-scheduler.sh [start|stop|restart|status]
scripts/airflow-worker.sh [start|stop|restart|status]
scripts/airflow-flower.sh [start|stop|restart|status]
```
* [Debug] start service manually, process running in foreground<br/>
<span style="color:red">Notification: `<airflow_venv>` path is different from venv created by `pre-deploy.sh`</span>
```python
# find airflow venv create by `deploy.sh`
''' Check `airflow_venv` in airflow/airflow-vars/airflow-<env>.yml '''
source <airflow_venv>/bin/activate

# [IMPORTANT!] export AIRFLOW_HOME
''' Check `airflow_home` in airflow/airflow-vars/airflow-<env>.yml '''
export AIRFLOW_HOME=<airflow_home>

# start airflow webserver
airflow webserver

# start airflow scheduler
airflow scheduler

# start airflow worker(celery)
airflow worker

# start ariflow flower
airflow flower
```

## TODO
* git ssh key in ansible script
* log rotation
* `airflow scheduler -D` not work with LocalExecutor|CeleryExecutor in osx 10.14.5

## Service Structure
* airflow/postgresql/redis service structure
```
<base_path>
└───airflow-app     <- path can be set by `airflow_home` variable
│   │   airflow.cfg
│   │   unittests.cfg
│   │
│   └───dags
│       └───airflow-maintainence-dags
│       └───adw
│       └───tags
│       └───...
│   │
│   └───plugins
│       └───event_plugins
│       └───...
│   │
└───logs    <- path can be set by `airflow_log` variable
│   └───dags
│   └───webserver
│   └───scheduler
│   └───worker
│   └───flower
│
└───venv       <--  path can be set by `airflow_venv` varaible
└───postgresql
│   │   postgresql-<pg_version>.tar.gz  <-- prepare this file first
│   └───postgresql-<pg_version>
│   └───pgsql
└───redis
│   │   redis-<redis_version>.tar.gz  <-- prepare this file first
│   └───redis-<redis_version>
│
└───airflow-operation <-- put this repo here
│   └───var
│   │   │   airflow-deployment-conf.sh  <-- record the variables after airflow deployment
└───airflow-sourcecode (opt)
└───airflow-plugins
```
