#!/bin/bash

echo_help() {
  echo "Usage: sudo $0 [options...]" >&2
  echo
  echo "   -d, --directory           directory where the command is going to be run"
  echo "   -p, --programname         name that the subprocess will have in supervisord"
  echo "   -r, --runcommand          command to run the program"
  echo "   -e, --environment         environment variables that the program will use, ex: 'PORT=9000,ENV=dev'"
  echo "   -m, --email               email address that will be notified if the program goes down"
  echo "   -u, --healthcheck         http url of your program that return 200 OK"
  echo "   -c, --configpath          path where the configuration file is going to be generated, default: /etc/supervisord.conf"
  echo
  echo "This script will install supervisord if is not present in your system."
  echo "Use sudo because we generate the config file by default in /etc/"
  exit 1
}

display_help() {
  if [ "$1" == "-h" ]; then
    echo_help
    exit 0
  fi
}

grab_options() {
  for i in "$@"; do
    case $i in
    -d=* | --directory=*)
      DIRECTORY="${i#*=}"
      shift # past argument=value
      ;;
    -p=* | --programname=*)
      PROGRAM_NAME="${i#*=}"
      shift # past argument=value
      ;;
    -r=* | --runcommand=*)
      COMMAND="${i#*=}"
      shift # past argument=value
      ;;
    -e=* | --environment=*)
      ENVIRONMENT="${i#*=}"
      shift # past argument=value
      ;;
    -m=* | --email=*)
      EMAIL="${i#*=}"
      shift # past argument=value
      ;;
    -u=* | --healthcheckurl=*)
      HEALTCHECK_URL="${i#*=}"
      shift # past argument=value
      ;;
    -c=* | --configpath=*)
      CONFIG_PATH="${i#*=}"
      shift # past argument=value
      ;;
    *)
      # unknown option
      ;;
    esac
  done
}

check_mandatory_options() {
  if [ -z "$COMMAND" ]; then
    echo "Command is mandatory, set it with -r or --runcommand"
    exit 1
  fi

  if [ -z "$EMAIL" ]; then
    echo "Email is mandatory, set it with -m or --email"
    exit 1
  fi
  if [ -z "$HEALTCHECK_URL" ]; then
    echo "Health check url is mandatory, set it with -h or --healthcheckurl"
    exit 1
  fi
  if [ -z "$DIRECTORY" ]; then
    echo "Directory is mandatory, set it with -d or --directory"
    exit 1
  fi
}

set_defaults_options() {
  if [ -z "$PROGRAM_NAME" ]; then
    PROGRAM_NAME="dummy-name"
  fi
  if [ -z "$CONFIG_PATH" ]; then
    CONFIG_PATH="/etc/supervisord.conf"
  fi
  ERROR_LOGS_PATH="/var/log/${PROGRAM_NAME}.err.log"
  OUT_LOGS_PATH="/var/log/${PROGRAM_NAME}.out.log"
}

show_config_information() {
  echo "This is the final config: "
  echo "directory = ${DIRECTORY}"
  echo "program name = ${PROGRAM_NAME}"
  echo "run command = ${COMMAND}"
  if [ -z "$ENVIRONMENT" ]; then
    echo "Environment is not set"
    ENVIRONMENT=""
  else
    echo "Environment is set"
  fi
  echo "email = ${EMAIL}"
  echo "healtch check url = ${HEALTCHECK_URL}"
  echo "error logs path = ${ERROR_LOGS_PATH}"
  echo "output logs path = ${OUT_LOGS_PATH}"
}

generate_config_file() {
  cat >${CONFIG_PATH} <<EOF
[inet_http_server]         ; inet (TCP) server disabled by default
port=127.0.0.1:9007        ; ip_address:port specifier, *:port for all iface
[supervisord]
logfile=/var/log/supervisor/supervisord.log ; main log file; default $CWD/supervisord.log
logfile_maxbytes=50MB        ; max main logfile bytes b4 rotation; default 50MB
logfile_backups=10           ; # of main logfile backups; 0 means none, default 10
loglevel=info                ; log level; default info; others: debug,warn,trace
pidfile=/tmp/supervisord.pid  ; supervisord pidfile; default supervisord.pid
nodaemon=false               ; start in foreground if true; default false
minfds=1024                  ; min. avail startup file descriptors; default 1024
minprocs=200                 ; min. avail process descriptors;default 200
[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface
[supervisorctl]

[program:${PROGRAM_NAME}]
directory=${DIRECTORY}
command=${COMMAND}
autostart=true
autorestart=true
stopsignal=QUIT
environment=${ENVIRONMENT}
stderr_logfile=${ERROR_LOGS_PATH}
stdout_logfile=${OUT_LOGS_PATH}

[eventlistener:${PROGRAM_NAME}-listener]
command=httpok --email=${EMAIL} -p <program_name> ${HEALTCHECK_URL}
events=TICK_60
EOF

  echo "Configuration file was successfully created in /etc/supervidord.conf"
}

try_install_supervisord() {
  if hash supervisord; then
    echo "supervisord is already installed"
  else
    Install supervisord
    pip install supervisor
    # This is to use httpok
    pip install superlance
    # IN AWS images: sudo yum install python-devel
    sudo apt-get install python-dev
  fi
}

display_help $1
grab_options $@
check_mandatory_options
set_defaults_options
show_config_information
generate_config_file
try_install_supervisord

echo "Run supervisord with 'supervisord' whenever you are ready to run your app/system."