#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <contracts_folder>"
    exit 1
fi

# Assign the arguments to variables
contracts_dir="$1"
rules_dirs=(
    # "mike-security"
    # "../semgrep-rules/rules/solidity"
    # "../semgrep-smart-contracts/solidity/security"
    "sandbox"
)

# Function to get simplified directory name
get_output_dir() {
    case "$1" in
        "mike-security") echo "mike-security" ;;
        "../semgrep-rules/rules/solidity") echo "semgrep-rules" ;;
        "../semgrep-smart-contracts/solidity/security") echo "semgrep-smart-contracts" ;;
        "sandbox") echo "sandbox" ;;
    esac
}

results_dir="contract-results"

# Ensure results directory exists
mkdir -p "$results_dir"

#####################################
# Do semgrep on contracts

# Export necessary variables for use in the subshell
export contracts_dir
export results_dir
export rules_dirs

# Initialize counter
counter=0
batch_size=20
files=()

echo "START: Cleaning up empty directories..."
find "$results_dir" -type d -empty -delete

echo "START: Cleanup complete."

# Find all .sol files in the contracts directory and process each one in parallel batches
find "$contracts_dir" -type f -name "*.sol" | while read -r sol_file; do
    files+=("$sol_file")
    ((counter++))

    if (( counter % batch_size == 0 )); then
        # Process the batch
        for file in "${files[@]}"; do
            for rules_dir in "${rules_dirs[@]}"; do
                (
                    output_dirname=$(get_output_dir "$rules_dir")
                    output_file="$results_dir/${output_dirname}/${file#"$contracts_dir/"}.txt"
                    mkdir -p "$(dirname "$output_file")"
                    semgrep --config="$rules_dir" "$file" --output="$output_file"
                    if [[ ! -s "$output_file" ]]; then
                        rm -f "$output_file"
                    fi
                ) &
            done
        done
        wait
        files=()
    fi
done

# Process remaining files if any
if (( ${#files[@]} > 0 )); then
    for file in "${files[@]}"; do
        for rules_dir in "${rules_dirs[@]}"; do
            (
                output_dirname=$(get_output_dir "$rules_dir")
                output_file="$results_dir/${output_dirname}/${file#"$contracts_dir/"}.txt"
                mkdir -p "$(dirname "$output_file")"
                semgrep --config="$rules_dir" "$file" --output="$output_file"
                if [[ ! -s "$output_file" ]]; then
                    rm -f "$output_file"
                fi
            ) &
        done
    done
    wait
fi

#####################################

echo "Parallel processing complete."

# Clean up empty directories
echo "END: Cleaning up empty directories..."
find "$results_dir" -type d -empty -delete

echo "END: Cleanup complete."
