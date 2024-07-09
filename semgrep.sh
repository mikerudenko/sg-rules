#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <contracts_folder>"
    exit 1
fi

# Assign the first argument to the contracts_dir variable
contracts_dir="$1"
results_dir="contract-results"

# Ensure results directory exists
mkdir -p "$results_dir"

#####################################
# Do semgrep on contracts

# Export necessary variables for use in the subshell
export contracts_dir
export results_dir

# Initialize counter
counter=0
batch_size=40
files=()

# Find all .sol files in the contracts directory and process each one in parallel batches
find "$contracts_dir" -type f -name "*.sol" | while read -r sol_file; do
  files+=("$sol_file")
  ((counter++))

  if (( counter % batch_size == 0 )); then
    # Process the batch
    for file in "${files[@]}"; do
      (
        output_file="$results_dir/${file#"$contracts_dir/"}.txt"
        mkdir -p "$(dirname "$output_file")"
        semgrep --config=semgrep-smart-contracts/solidity/mike-security "$file" --output="$output_file"
        if [[ ! -s "$output_file" ]]; then
          rm -f "$output_file"
        fi
      ) &
    done
    wait
    files=()
  fi
done

# Process remaining files if any
if (( ${#files[@]} > 0 )); then
  for file in "${files[@]}"; do
    (
      output_file="$results_dir/${file#"$contracts_dir/"}.txt"
      mkdir -p "$(dirname "$output_file")"
      semgrep --config=semgrep-smart-contracts/solidity/mike-security "$file" --output="$output_file"
      if [[ ! -s "$output_file" ]]; then
        rm -f "$output_file"
      fi
    ) &
  done
  wait
fi

#####################################

echo "Parallel processing complete."
