#!/bin/bash

if [ -z "$1" ]; then
    echo "Error: No git repository"
    echo "Usage: ./run.sh <git_repo>"
    exit 1
fi

repo=$1
repo_name=$(basename "$repo" .git)
PROGRAM="$repo_name"

echo "Cloning the repository..."
git clone --depth 1 "$repo" 

cd "$repo_name"

echo "Installing the dependencies..."

pip3 install .[dev,test,tests,testing]

# Install additional requirements if available (within root + 2 nest levels excluding env/ folder)
find . -maxdepth 3 -type d -name "env" -prune -o -type f -name "*.txt" -print | while read -r file; do
    if [ -f "$file" ]; then
        pip3 install -r "$file"
    fi
done

echo "Dependencies installed."
echo "Running Pynguin on all Python modules..."

BASEDIR=/app/"$repo_name"
logs_dir="$BASEDIR"/"logs_pynguin"
output_dir="$BASEDIR"/"tests2_pynguin"
summary_file="$logs_dir"/summary.csv

mkdir -p "$BASEDIR" "$logs_dir" "$output_dir"

# Create necessary directories
mkdir -p "$logs_dir"

# Initialize summary file
echo "module,run_status,time_duration_seconds" > "$summary_file"

# Find Python modules and process each
for file_path in $(find "$PROGRAM" -name "*.py"); do
    module=$(echo "$file_path" | sed 's|/|.|g; s|\.py$||' | sort | uniq)

    echo -e "\n\n\n--------------\nRunning Pynguin on $module\n"
    log_file="$logs_dir/${module//./_}.log"

    # Measure execution time
    start_time=$(date +%s)

    # show the time now in utc -3
    echo "Start time: $(date)"
    timeout 22m pynguin -v --project-path . --output-path "$output_dir" --module-name "$module" &> "$log_file"
    exit_code=$?
    end_time=$(date +%s)

    # Calculate runtime in seconds
    duration=$((end_time - start_time))

    # Check the exit code and log results
    if [ $exit_code -eq 124 ]; then
        echo "Pynguin timed out for module $module" | tee -a "$log_file"
        echo "$module,timeout,$duration" >> "$summary_file"
    elif [ $exit_code -eq 0 ]; then
        echo "$module,ok,$duration" >> "$summary_file"
    else
        echo "Pynguin failed for module $module" | tee -a "$log_file"
        echo "$module,failed,$duration" >> "$summary_file"
    fi
done

# add chmod to the logs directory
chmod -R 777 "$BASEDIR"

zip -r "$BASEDIR".zip "$BASEDIR"

echo "Script completed. Summary written to $summary_file"