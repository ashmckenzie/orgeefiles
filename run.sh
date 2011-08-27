#!/bin/bash

DIR=`dirname $0`
cd ${DIR}

growlnotify -m "Attempting to move files.."

source /usr/local/rvm/scripts/rvm

output=`./orgeefiles.rb --forreal | grep 'Rsync' | awk -F "Rsync'ing " '{ print $2 }' | awk -F ' to' '{ print $1 }'`

for f in ${output}
do
  file=`basename ${f}`
  growlnotify -s -m "Moved ${file}"
done

growlnotify -m "Done moving files!"
