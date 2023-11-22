#!/bin/bash

# Get the number of processes for a specific user
#user=$1
process_count=$(ls /etc | wc -l)

echo $process_count