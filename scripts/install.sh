#!/bin/bash
set -x

# check if the user has provided a URL
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Please provide a URL to the git repository and a second argument"
    exit 1
fi

# Clone project and create environment

# Split the input into link and sha
IFS=';' read -r url target_sha <<< "$1"

ALGO=$2

# Output the url
echo "Url: $url"
echo "Sha: $target_sha"

git clone --depth=5 $url
folder=$(basename $url .git)

# Navigate to project directory
cd $folder || exit

# If sha is not empty, attempt to checkout the sha
if [ -n "$target_sha" ]; then
  echo "SHA exists: $target_sha"
  # Assuming you have already cloned the repo and are in the repo directory
  git checkout "$target_sha"
else
  echo "SHA is empty, no checkout performed."
fi

sha=$(git rev-parse HEAD | cut -c1-7)
echo "current sha commit: $sha"
echo "project url: $url"

# Create and activate virtual environment
python3 -m venv env
source env/bin/activate

# Install dependencies
pip3 install .[dev,test,tests,testing]

# Install additional requirements if available (within root + 2 nest levels excluding env/ folder)
find . -maxdepth 3 -type d -name "env" -prune -o -type f -name "*.txt" -print | while read -r file; do
    if [ -f "$file" ]; then
        pip3 install -r "$file"
    fi
done

# Install pythonmop (assuming it's in a sibling directory named 'mop-with-dynapt')
if [ "$ALGO" != "ORIGINAL" ]; then
    pip3 install pytest-json-report memray pytest-memray pytest-cov pytest-env pytest-rerunfailures pytest-socket pytest-django
    cd ../mop-with-dynapt || exit
    pip3 install .
    sudo apt-get install python3-tk -y
else
    pip3 install pytest-json-report pytest-cov pytest-env pytest-rerunfailures pytest-socket pytest-django
fi

cd -
deactivate