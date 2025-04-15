# Python Web App Setup & Runner Script

This project includes a shell script that sets up and runs a Python web application (Django, Flask, or Streamlit) from either a **Git repository** or a **local project directory**.

## Features

- Accepts either a Git repository URL or local path
- Clones the repo if a URL is provided
- Uses the local path if provided
- Creates and activates a virtual environment
- Installs Python dependencies from `requirements.txt` (or generates one if missing)
- Automatically detects the application type (Django, Flask, or Streamlit)
- Runs the appropriate application
- Supports local or remote deployment via SSH

## Prerequisites

Make sure your system has:

- Python 3.7+ Or Specific for your application needs
- `git` (version 2.20 or higher)
- `pip` (version 21.0 or higher)
- `bash` (for running the script)
- `virtualenv` or `python -m venv` for creating virtual environments

## Usage

Run the script with the following parameters:

```bash
./pylaunch.sh --project_name <project_name> --project_path <project_path> [--ssh_host <ssh_host>] [--main_file <main_file>] [--branch_name <branch_name>]
```

### Parameters

- **--project_name**  
    The name of your project. This identifier helps manage multiple projects.

- **--project_path**  
    A local path or Git repository URL pointing to the project. If a URL is provided, the repository will be cloned.

- **--ssh_host** (optional)  
    The SSH host for remote deployment. Include this parameter when deploying your application remotely.

- **--main_file** (optional)  
    The main file to run for local projects if it differs from the auto-detected entry point.

- **--branch_name** (optional)  
    Specify a branch name when cloning a Git repository if you want to use a branch other than the default.
