# Python Web App Setup & Runner Script

This project includes a shell script that sets up and runs a Python web application (Django, Flask, or Streamlit) from either a **Git repository** or a **local project directory**.

## Features

- Accepts either a Git repository URL or local path
- Clones the repo if a URL is provided
- Uses the local path if provided
- Creates and activates a virtual environment
- Installs Python dependencies from `requirements.txt`
- Automatically runs the appropriate application

## Prerequisites

Make sure your system has:

- Python 3.7+
- `git`
- `pip`
- `bash`
- `virtualenv` or `python -m venv`
