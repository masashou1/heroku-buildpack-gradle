#!/usr/bin/env bash

export BUILDPACK_STDLIB_URL="https://lang-common.s3.amazonaws.com/buildpack-stdlib/v7/stdlib.sh"

gradle_build_file() {
  local buildDir=${1}
  if [ -f ${buildDir}/build.gradle.kts ]; then
    echo "${buildDir}/build.gradle.kts"
  else
    echo "${buildDir}/build.gradle"
  fi
}

has_stage_task() {
  local gradleFile="$(gradle_build_file ${1})"
   test -f ${gradleFile} &&
     test -n "$(grep "^ *task *stage" ${gradleFile})"
}

is_spring_boot() {
  local gradleFile="$(gradle_build_file ${1})"
   test -f ${gradleFile} &&
     (
       test -n "$(grep "^[^/].*org.springframework.boot:spring-boot" ${gradleFile})" ||
       test -n "$(grep "^[^/].*spring-boot-gradle-plugin" ${gradleFile})" ||
       test -n "$(grep "^[^/].*id.*org.springframework.boot" ${gradleFile})"
     ) &&
     test -z "$(grep "org.grails:grails-" ${gradleFile})"
}

is_ratpack() {
  local gradleFile="$(gradle_build_file ${1})"
  test -f ${gradleFile} &&
    test -n "$(grep "^[^/].*io.ratpack.ratpack" ${gradleFile})"
}

is_grails() {
  local gradleFile="$(gradle_build_file ${1})"
   test -f ${gradleFile} &&
     test -n "$(grep "^[^/].*org.grails:grails-" ${gradleFile})"
}

is_webapp_runner() {
  local gradleFile="$(gradle_build_file ${1})"
  test -f ${gradleFile} &&
    test -n "$(grep "^[^/].*io.ratpack.ratpack" ${gradleFile})"
}

create_build_log_file() {
  local buildLogFile=".heroku/gradle-build.log"
  echo "" > $buildLogFile
  echo "$buildLogFile"
}

# By default gradle will write its cache in `$BUILD_DIR/.gradle`. Rather than
# using the --project-cache-dir option, which muddies up the command, we
# symlink this directory to the cache.
create_project_cache_symlink() {
  local buildpackCacheDir="${1:?}/.gradle-project"
  local projectCacheLink="${2:?}/.gradle"
  if [ ! -d "$projectCacheLink" ]; then
    mkdir -p "$buildpackCacheDir"
    ln -s "$buildpackCacheDir" "$projectCacheLink"
    trap "rm -f $projectCacheLink" EXIT
  fi
}

# sed -l basically makes sed replace and buffer through stdin to stdout
# so you get updates while the command runs and dont wait for the end
# e.g. sbt stage | indent
output() {
  local logfile="$1"
  local c='s/^/       /'

  case $(uname) in
    Darwin) tee -a "$logfile" | sed -l "$c";; # mac/bsd sed: -l buffers on line boundaries
    *)      tee -a "$logfile" | sed -u "$c";; # unix/gnu sed: -u unbuffered (arbitrary) chunks of data
  esac
}

cache_copy() {
  rel_dir=$1
  from_dir=$2
  to_dir=$3
  rm -rf $to_dir/$rel_dir
  if [ -d $from_dir/$rel_dir ]; then
    mkdir -p $to_dir/$rel_dir
    cp -pr $from_dir/$rel_dir/. $to_dir/$rel_dir
  fi
}

install_jdk() {
  echo "common.sh install_jdk() start"
  local install_dir=${1:?}
  local cache_dir=${2:?}

  echo "common.sh install_jdk() 1"

  let start=$(nowms)
  echo "common.sh install_jdk() 1-1"
  JVM_COMMON_BUILDPACK=${JVM_COMMON_BUILDPACK:-https://buildpack-registry.s3.amazonaws.com/buildpacks/heroku/jvm.tgz}
  echo "common.sh install_jdk() 1-2"
  mkdir -p /tmp/jvm-common
  echo "common.sh install_jdk() 1-3"
  curl --retry 3 --silent --location $JVM_COMMON_BUILDPACK | tar xzm -C /tmp/jvm-common --strip-components=1
  echo "common.sh install_jdk() 1-4"
  source /tmp/jvm-common/bin/util
  echo "common.sh install_jdk() 1-5"
  source /tmp/jvm-common/bin/java
  echo "common.sh install_jdk() 1-6"
  source /tmp/jvm-common/opt/jdbc.sh
  echo "common.sh install_jdk() 1-7"
  mtime "jvm-common.install.time" "${start}"

  echo "common.sh install_jdk() 2"

  let start=$(nowms)
  install_java_with_overlay "${install_dir}" "${cache_dir}"
  mtime "jvm.install.time" "${start}"
  echo "common.sh install_jdk() end"
}
