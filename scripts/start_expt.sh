#!/bin/bash
# ./start_expt.sh -b pagerank -c none -k 0 -r full
origargs=$@ 
SPARK_HOME=/root/spark


while [[ $# > 1 ]]
do
key="$1"

case $key in
    -b|--benchmark)
    BENCHMARK="$2"
    shift # past argument
    ;;
    -c|--checkpoint)
    CKPT="$2"
    shift # past argument
    ;;
    -k|--tokill)
    TOKILL="$2"
    shift # past argument
    ;;
    -r|--replenish)
    REPLENISH="$2"
    shift # past argument
    ;;
    --default)
    DEFAULT=YES
    ;;
    *)
            # unknown option
    ;;
esac
shift # past argument or value
done


resultshome="results"
mkdir $resultshome
progdir="$BENCHMARK"_"$CKPT"_"$TOKILL"
resultsdir=$resultshome/$progdir
mkdir $resultsdir

echo "-------------- Created Directories : $resultsdir"

date >> "$resultsdir"/start
echo "$origargs" >> "$resultsdir"/args
echo "$origargs" >> /root/latest
cp start_expt.sh "$resultsdir"/start_expt.sh

outputfile=$resultsdir/time

echo "--------------- Spark Config --------------------------"

sparkconfig=""
if [ "$CKPT" == "opt" ];
then
    $sparkconfig="spark.checkpointing.policy    opt 
spark.checkpointing.tau      0.2
spark.checkpointing.dir     /root/ckpts"

    echo $sparkconfig >> $SPARK_HOME/conf/spark-defaults.conf
    echo "RSYNC REQUIRED. NOT SUPPORTED YET, exiting"
    exit

elif [ "$CKPT" == "none" ];
then
    $sparkconfig=""
    echo "Default conf is good conf, nothing to do"
fi

echo "-------------------- Spark --------------------------"

if [ "$BENCHMARK" == "pagerank" ];
then
    echo "$BENCHMARK !"
    programname="graphX.LiveJournalPageRank"
    params="s3n://prtk1/sparkdata/part-r-0000[1-7] --numEpart=20"

elif [ "$BENCHMARK" == "als" ];
then
    echo "$BENCHMARK !"
    programname="mllib.MovieLensALS"
    params="s3n://lassALS/movielens00[6-7][0-9].txt --rank 5"

elif [ "$BENCHMARK" == "kmeans" ];
then
    echo "$BENCHMARK !"
    programname="mllib.DenseKMeans"
    params="s3n://lassKmeans/kmeansdata[1-3][0-9].txt -k 100"

fi
echo "run-example $programname $params"

nohup time $SPARK_HOME/bin/run-example $programname $params > $outputfile 2>&1 &

echo "job should be running. Now sleeping...?"

### Expt has started. 
sleeptime=1200 #20 minutes default
#
sleep $sleeptime

#kill nodes 

echo "------------- Wake up to kill nodes -------------"
slavestokill=`cat $SPARK_HOME/conf/slaves | head -n $TOKILL`

pssh -H "$slavestokill" "$SPARK_HOME/scripts/kill-node.sh"

#This kills spark worker AND hdfs

if [ "$REPLENISH" == "full" ];
then
    sleep 100
    $SPARK_HOME/sbin/start-all.sh
fi

#

echo ">>>>>>>>>> NOW WAIT FOR EXPERIMENT TO FINISH >>>>>>>>>>>>>> "


while true 
do
    sleep 10
    wget -q http://localhost:8080/json -o json
    appstate=`cat json | jq '.activeapps|.[0].state'`
    numrunning=`cat json | jq '.activeapps|length'`
    if [ "$appstate" != "\"RUNNING\"" && "$numrunning" == 0 ];
    then
	echo "EXPT DONE!!!!"
	exit 
    fi    
done

