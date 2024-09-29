#!/bin/bash

# Check if exactly one repository URL is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <testing-repo-url>"
    exit 1
fi

# Assign the command line argument to the testing repository variable
repo_url_with_sha="$1"

# Split the input into link and sha
IFS=';' read -r TESTING_REPO_URL target_sha <<< "$repo_url_with_sha"

# Output the url
echo "Url: $TESTING_REPO_URL"
echo "Sha: $target_sha"

# Fixed repository URL for the mop-with-dynapt project
PYMOP_REPO_URL="https://$GH_ACCESS_TOKEN@github.com/SoftEngResearch/mop-with-dynapt.git"

# Extract the repository name from the URL
TESTING_REPO_NAME=$(basename -s .git "$TESTING_REPO_URL")

# Create a new directory name by appending _PyMOP to the repository name
CLONE_DIR="${TESTING_REPO_NAME}_PyMOP"

# Create the directory if it does not exist
mkdir -p "$CLONE_DIR"

# Navigate to the project directory
cd "$CLONE_DIR" || { echo "Failed to enter directory $CLONE_DIR"; exit 1; }

# Clone the testing repository
git clone "$TESTING_REPO_URL" || { echo "Failed to clone $TESTING_REPO_URL"; exit 1; }

# Clone the mop-with-dynapt repository
git clone "$PYMOP_REPO_URL" || { echo "Failed to clone $PYMOP_REPO_URL"; exit 1; }

# Navigate to the testing project directory
cd "$TESTING_REPO_NAME" || { echo "Failed to enter directory $TESTING_REPO_NAME"; exit 1; }

# Create a virtual environment in the project directory using Python's built-in venv
python -m venv venv

# Activate the virtual environment
source venv/bin/activate

# Announce setup of testing repository
echo "Setting up testing repository..."

# Install additional requirements if available
for file in *.txt; do
    if [ -f "$file" ]; then
        pip install -r "$file" || { echo "Failed to install requirements from $file"; exit 1; }
    fi
done

# Install dependencies
pip install .[dev,test,tests,testing] || { echo "Failed to install dependencies"; exit 1; }

# Navigate to the parent directory
cd ..

# Announce setup of PyMOP repository
echo "Setting up PyMOP repository..."
cd mop-with-dynapt || { echo "Failed to enter directory mop-with-dynapt"; exit 1; }

# Checkout the specific branch
git checkout add_statistics_new || { echo "Failed to checkout branch add_statistics_new"; exit 1; }

# Install the project in editable mode with dev dependencies
pip install -e ".[dev]" || { echo "Failed to install mop-with-dynapt"; exit 1; }

# Navigate back to the testing repository directory
cd ..
cd "$TESTING_REPO_NAME" || { echo "Failed to return to directory $TESTING_REPO_NAME"; exit 1; }

pip3 install pytest-json-report

# Run tests with pytest
pytest --path="$PWD"/../../Specs/PyMOP --algo=D --continue-on-collection-errors --json-report --json-report-indent=2 --statistics --statistics_file="D".json

# Deactivate the virtual environment
deactivate

# delete venv folder
rm -rf ./venv

mv ./.report.json ../../results/pymop/.report.json
mv ./D-full.json ../../results/pymop/D-full.json
mv ./D-time.json ../../results/pymop/D-time.json
mv ./D-violations.json ../../results/pymop/D-violations.json

# Return to the initial script directory
cd - || exit