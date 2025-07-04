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

# install poetry
curl -sSL https://install.python-poetry.org | python3 -

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install additional requirements if available (within root + 2 nest levels excluding venv/ folder)
find . -maxdepth 3 -type d -name "venv" -prune -o -type f -name "*.txt" -print | while read -r file; do
    if [ -f "$file" ]; then
        pip3 install -r "$file"
    fi
done

if [ -f pyproject.toml ]; then

  if grep -q "\[tool.poetry\]" "$PYPROJECT"; then
    echo "Poetry detected. Installing with Poetry..."
    poetry install
  elif grep -q "setuptools" "$PYPROJECT"; then
    echo "Setuptools project detected."
    echo "Recommended install: pip install ."
    pip3 install .[dev,test,tests,testing]
  elif grep -q "build-backend" "$PYPROJECT"; then
    backend=$(grep "build-backend" "$PYPROJECT" | cut -d'"' -f2)
    echo "Custom PEP 517 build backend detected: $backend"
    pip3 install .[dev,test,tests,testing]
  else
    echo "pyproject.toml found but backend is unclear."
    echo "Fallback install: pip install ."
    pip3 install .[dev,test,tests,testing]
  fi

elif [ -f setup.py ]; then
  echo "setup.py found. Proceeding with pip installation..."
  pip3 install .[dev,test,tests,testing]
fi

pip3 install pytest
pip3 install pandas
pip3 install numpy
pip3 install matplotlib
pip3 install absl-py==2.1.0 astunparse==1.6.3 blinker==1.8.2 forbiddenfruit==0.1.4 gast==0.6.0 google-pasta==0.2.0 grpcio==1.67.0 h5py==3.12.1 JPype1==1.5.0 keras==3.6.0 libclang==18.1.1 Markdown==3.7 markdown-it-py==3.0.0 mdurl==0.1.2 ml-dtypes==0.4.1 namex==0.0.8 nltk==3.9.1 numpy==2.0.2 opt_einsum==3.4.0 optree==0.13.0 packaging==24.1 protobuf==5.28.3 Pygments==2.18.0 regex==2024.9.11 rich==13.9.3 scipy==1.14.1 tensorboard==2.18.0 tensorboard-data-server==0.7.2 tensorflow==2.18.0 termcolor==2.5.0 tk==0.1.0 tornado==6.4.1 tqdm==4.66.5 typing_extensions==4.12.2 Werkzeug==3.0.6 wrapt==1.16.0
pip3 install pytest-json-report memray pytest-memray pytest-cov pytest-env pytest-rerunfailures pytest-socket pytest-django setuptools==75.8.0

# Install pythonmop (assuming it's in a sibling directory named 'mop-with-dynapt')
if [ "$ALGO" != "ORIGINAL" ]; then
    cd ../mop-with-dynapt || exit
    pip3 install .
    sudo apt-get install python3-tk -y
fi

cd -
deactivate
