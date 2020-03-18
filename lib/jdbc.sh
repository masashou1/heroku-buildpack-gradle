#!/usr/bin/env bash
echo "set_jdbc_url start"
set_jdbc_url() {
echo "set_jdbc_url 1"
  local db_url=${1}
echo "set_jdbc_url 2"
  local env_prefix=${2:-"JDBC_DATABASE"}
echo "set_jdbc_url 3"
  if [ -z "$(eval echo "\${${env_prefix}_URL:-}")" ]; then
echo "set_jdbc_url 3-1"
      local db_protocol
echo "set_jdbc_url 3-2"
      db_protocol=$(expr "$db_url" : "\(.\+\)://")
echo "set_jdbc_url 3-3"
      if [ "$db_protocol" = "postgres" ]; then
echo "set_jdbc_url 3-3-1"
        local jdbc_protocol="jdbc:postgresql"
echo "set_jdbc_url 3-3-2"
        if [ "${CI:-}" != "true" ]; then
          local db_default_args="&sslmode=require"
        else
          local db_default_args=""
        fi
echo "set_jdbc_url 3-3-3"
      elif [ "$db_protocol" = "mysql" ]; then
echo "set_jdbc_url 3-3-4"
        local jdbc_protocol="jdbc:mysql"
      fi
echo "set_jdbc_url 3-4"
      if [ -n "$jdbc_protocol" ]; then
echo "set_jdbc_url 3-4-1"
        local db_user
echo "set_jdbc_url 3-4-2"
        db_user=$(expr "$db_url" : "${db_protocol}://\(.\+\):\(.\+\)@")
echo "set_jdbc_url 3-4-3"
        local db_prefix="${db_protocol}://${db_user}:"
echo "set_jdbc_url 3-4-4"
        local db_pass
echo "set_jdbc_url 3-4-5"
        db_pass=$(expr "$db_url" : "${db_prefix}\(.\+\)@")
echo "set_jdbc_url 3-4-6"
        db_prefix="${db_prefix}${db_pass}@"
echo "set_jdbc_url 3-4-7"
        local db_host_port
echo "set_jdbc_url 3-4-8"
        db_host_port=$(expr "$db_url" : "${db_prefix}\(.\+\)/")
echo "set_jdbc_url 3-4-9"
        db_prefix="${db_prefix}${db_host_port}/"
echo "set_jdbc_url 3-4-10"
        local db_suffix
echo "set_jdbc_url 3-4-11"
        db_suffix=$(expr "$db_url" : "${db_prefix}\(.\+\)")
echo "set_jdbc_url 3-4-12"
        if echo "$db_suffix" | grep -qi "?"; then
echo "set_jdbc_url 3-4-12-1"
          local db_args="&user=${db_user}&password=${db_pass}"
        else
echo "set_jdbc_url 3-4-12-1"
          local db_args="?user=${db_user}&password=${db_pass}"
        fi
echo "set_jdbc_url 3-4-13"
        if [ -n "$db_host_port" ] &&
             [ -n "$db_suffix" ] &&
             [ -n "$db_user" ] &&
             [ -n "$db_pass" ]; then
echo "set_jdbc_url 3-4-13-1"
          eval "export ${env_prefix}_URL=\"${jdbc_protocol}://${db_host_port}/${db_suffix}${db_args}${db_default_args}\""
echo "set_jdbc_url 3-4-13-2"
          eval "export ${env_prefix}_USERNAME=\"${db_user}\""
echo "set_jdbc_url 3-4-13-3"
          eval "export ${env_prefix}_PASSWORD=\"${db_pass}\""
echo "set_jdbc_url 3-4-13-4"
        fi
echo "set_jdbc_url 3-4-14"
      fi
echo "set_jdbc_url 3-5"
  fi
echo "set_jdbc_url 4"
}
echo "set_jdbc_url end"
echo "jdbc.sh 1"
if [ -n "${DATABASE_URL:-}" ]; then
  echo "jdbc.sh 1-1"
  set_jdbc_url "$DATABASE_URL"
  if [ -n "${DATABASE_CONNECTION_POOL_URL:-}" ]; then
    set_jdbc_url "$DATABASE_CONNECTION_POOL_URL"
  fi
elif [ -n "${JAWSDB_URL:-}" ]; then
  echo "jdbc.sh 1-2"
  set_jdbc_url "$JAWSDB_URL"
elif [ -n "${JAWSDB_MARIA_URL:-}" ]; then
  echo "jdbc.sh 1-3"
  set_jdbc_url "$JAWSDB_MARIA_URL"
elif [ -n "${CLEARDB_DATABASE_URL:-}" ]; then
  echo "jdbc.sh 1-4"
  set_jdbc_url "$CLEARDB_DATABASE_URL"
fi
echo "jdbc.sh 2"
if [ "${DISABLE_SPRING_DATASOURCE_URL:-}" != "true" ] &&
   [ -n "${JDBC_DATABASE_URL:-}" ] &&
   [ -z "${SPRING_DATASOURCE_URL:-}" ] &&
   [ -z "${SPRING_DATASOURCE_USERNAME:-}" ] &&
   [ -z "${SPRING_DATASOURCE_PASSWORD:-}" ]; then
  export SPRING_DATASOURCE_URL="$JDBC_DATABASE_URL"
  export SPRING_DATASOURCE_USERNAME="${JDBC_DATABASE_USERNAME:-}"
  export SPRING_DATASOURCE_PASSWORD="${JDBC_DATABASE_PASSWORD:-}"
fi
echo "jdbc.sh 3"
for dbUrlVar in $(env | awk -F "=" '{print $1}' | grep "HEROKU_POSTGRESQL_.*_URL"); do
  set_jdbc_url "$(eval echo "\$${dbUrlVar}")" "${dbUrlVar//_URL/}_JDBC"
done
echo "jdbc.sh 4"
