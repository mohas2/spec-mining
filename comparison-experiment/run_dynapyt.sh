#!/bin/bash

# Check if exactly one repository URL is provided, and exit if not
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <testing-repo-url>"
    exit 1
fi

# Assign the provided argument (repository URL) to a variable
repo_url_with_sha="$1"

# Split the input into link and sha
IFS=';' read -r TESTING_REPO_URL target_sha <<< "$repo_url_with_sha"

# Output the url
echo "Url: $TESTING_REPO_URL"
echo "Sha: $target_sha"

# Define the fixed repository URL for the DynaPyt project
DYNAPYT_REPO_URL="https://github.com/sola-st/DynaPyt.git"

# Extract the repository name from the provided URL, removing the .git suffix
TESTING_REPO_NAME=$(basename -s .git "$TESTING_REPO_URL")

# Define a new directory name by appending '_DynaPyt' to the repository name
CLONE_DIR="${TESTING_REPO_NAME}_DynaPyt"

# Create the directory if it does not exist
mkdir -p "$CLONE_DIR"

# Change to the newly created directory or exit if it fails
cd "$CLONE_DIR" || { echo "Failed to enter directory $CLONE_DIR"; exit 1; }

# Clone the DynaPyt repository into the current directory
git clone "$DYNAPYT_REPO_URL" || { echo "Failed to clone $DYNAPYT_REPO_URL"; exit 1; }

# Specify the path of the source file to be copied (adjust the source path as necessary)
SOURCE_FILE="$PWD/../Specs/DynaPyt/Combined_Specs.py"
# Define the destination directory in the cloned DynaPyt repository
DESTINATION_DIR="$PWD/DynaPyt/src/dynapyt/analyses"

# Check if the source file exists before attempting to copy it
if [ -f "$SOURCE_FILE" ]; then
    cp "$SOURCE_FILE" "$DESTINATION_DIR"
else
    echo "Source file does not exist: $SOURCE_FILE"
    exit 1
fi

# Navigate into the cloned DynaPyt repository
cd DynaPyt

# Create a Python virtual environment in the current directory
python -m venv venv

# Activate the newly created virtual environment
source venv/bin/activate

# Install the required dependencies for DynaPyt and the package itself
pip install -r requirements.txt
pip install .
pip install numpy
pip install scipy
pip install requests

# Install pytest and a few common plugins
pip3 install pytest-json-report pytest-cov pytest-env pytest-rerunfailures pytest-socket pytest-django

# Clone the testing repository into the specified subdirectory
git clone --depth 1 "$TESTING_REPO_URL" ./test/PythonRepos/$TESTING_REPO_NAME || { echo "Failed to clone $TESTING_REPO_URL"; exit 1; }

# Create a directory to hold the combined specs for testing
mkdir -p under_test

# Copy the testing repository into the under_test directory, appending '_Combined_Specs' to the name
cp -r ./test/PythonRepos/$TESTING_REPO_NAME ./under_test/${TESTING_REPO_NAME}_Combined_Specs

# Navigate to the copied testing repository
cd ./under_test/${TESTING_REPO_NAME}_Combined_Specs

# If sha is not empty, attempt to checkout the sha
if [ -n "$target_sha" ]; then
  echo "SHA exists: $target_sha"
  # Assuming you have already cloned the repo and are in the repo directory
  git fetch --depth 1 origin "$target_sha"
  git checkout "$target_sha"
else
  echo "SHA is empty, no checkout performed."
fi

# Install any additional dependencies listed in the repository's requirement files
for file in *.txt; do
    if [ -f "$file" ]; then
        pip install -r "$file"
    fi
done

# Ensure that the package is installed with all necessary dependencies for testing, using a custom install script if available
if [ -f myInstall.sh ]; then
    bash ./myInstall.sh
else
    pip install .[dev,test,tests,testing]
fi

# Record the start time of the instrumentation process
START_TIME=$(python -c 'import time; print(time.time())')

# Run DynaPyt instrumentation for analysis
python -m dynapyt.run_instrumentation --dir . --analysis dynapyt.analyses.Combined_Specs.Combined_Specs

# Record the end time and calculate the instrumentation duration
END_TIME=$(python -c 'import time; print(time.time())')
INSTRUMENTATION_TIME=$(python -c "print($END_TIME - $START_TIME)")

# Create a Python script to run all tests in parallel with 8 threads using pytest
printf "import pytest\n\npytest.main(['--import-mode=importlib', '--continue-on-collection-errors'])" > run_all_tests.py

# Record the start time of the test execution
TEST_START_TIME=$(python -c 'import time; print(time.time())')

# Run the tests and output the results to a file

python -m dynapyt.run_analysis --entry run_all_tests.py --analysis dynapyt.analyses.Combined_Specs.Combined_Specs > ${TESTING_REPO_NAME}_Combined_Specs_output.txt

# Record the end time and calculate the test execution duration
TEST_END_TIME=$(python -c 'import time; print(time.time())')
TEST_TIME=$(python -c "print($TEST_END_TIME - $TEST_START_TIME)")

# Display the last few lines of the test output for quick status check
tail -n 3 ${TESTING_REPO_NAME}_Combined_Specs_output.txt

# Navigate back to the root project directory
cd ../..

# Deactivate the virtual environment
deactivate

# Clean up by removing the virtual environment
rm -rf venv

# Move back to the parent directory
cd ..

# Save the instrumentation time, test time, and results to a new file
RESULTS_FILE="../results/dynapyt/${TESTING_REPO_NAME}_results.txt"

# Write the instrumentation and test times to the results file
echo "Instrumentation Time: ${INSTRUMENTATION_TIME}s" > $RESULTS_FILE
echo "Test Time: ${TEST_TIME}s" >> $RESULTS_FILE

# Copy the test output file to the current directory
cp "./DynaPyt/under_test/${TESTING_REPO_NAME}_Combined_Specs/dynapyt_statistics.txt" ../results/dynapyt/
cp "./DynaPyt/under_test/${TESTING_REPO_NAME}_Combined_Specs/${TESTING_REPO_NAME}_Combined_Specs_output.txt" ../results/dynapyt/
