#!/usr/bin/env bash

#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

sbin="/root/spark/sbin"
sbin=`cd "$sbin"; pwd`

. "$sbin/spark-config.sh"

. "$SPARK_PREFIX/bin/load-spark-env.sh"

# do before the below calls as they exec
if [ -e "$sbin"/../tachyon/bin/tachyon ]; then
  "$sbin/slaves.sh" cd "$SPARK_HOME" \; "$sbin"/../tachyon/bin/tachyon killAll tachyon.worker.Worker
fi

if [ "$SPARK_WORKER_INSTANCES" = "" ]; then
  "$sbin"/spark-daemon.sh stop org.apache.spark.deploy.worker.Worker 1
else
  for ((i=0; i<$SPARK_WORKER_INSTANCES; i++)); do
    "$sbin"/spark-daemon.sh stop org.apache.spark.deploy.worker.Worker $(( $i + 1 ))
  done
fi

echo "STOPPING HDFS NOW"

cd /root/persistent-hdfs/bin

./hadoop-daemon.sh stop tasktracker

./hadoop-daemon.sh stop datanode

echo "__________________ ALL STOPPED ___________________ "

#./hadoop-daemon.sh start datanode

#./hadoop-daemon.sh start tasktracker
