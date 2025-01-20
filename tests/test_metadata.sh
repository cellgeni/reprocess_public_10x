#!/bin/bash
set -e

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <GSE_ID> <sample_list>"
    exit 1
fi

SERIES=$1
SAMPLE_LIST=${2:-""}
OUTPUT_DIR="output/$SERIES"

# Create output directory and copy all scripts
mkdir -p $OUTPUT_DIR
cp ./scripts/* $OUTPUT_DIR
cd $OUTPUT_DIR

# Load metadata
echo "Loading metadata for $SERIES $SAMPLE_LIST"
./collect_metadata.sh $SERIES $SAMPLE_LIST

# Test output
for file in test_data/$SERIES/*
do
  filename=$(basename $file)
  echo "Testing $file"

  # Check if the expected output file is created
  if [ ! -f $filename ]
  then
    echo "❌ERROR: Expected output file $filename not found!"
    exit 1
  fi

  # Check if the file is not empty
  if [ ! -s $filename ]
  then
    echo "❌ERROR: Output file $filename is empty!"
    exit 1
  fi

  # Compare the actual output with the expected output
  if ! diff -q $filename $file
  then
    echo "❌ERROR: Output file $filename does not match expected output!"
    exit 1
  fi
done

# Print Success
echo "✅$SERIES: All tests passed!"
