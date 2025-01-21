#!/usr/bin/env bash
#################################################
# Please do not make any changes to this file,  #
# change the variables in webui-user.sh instead #
#################################################
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# If run from macOS, load defaults from webui-macos-env.sh
if [[ "$OSTYPE" == "darwin"* ]]; then     if [[ -f "$SCRIPT_DIR"/webui-macos-env.sh ]];         then         source "$SCRIPT_DIR"/webui-macos-env.sh;     fi; fi
# Read variables from webui-user.sh
# shellcheck source=/dev/null
if [[ -f "$SCRIPT_DIR"/webui-user.sh ]]; then     source "$SCRIPT_DIR"/webui-user.sh; fi
# If $venv_dir is "-", then disable venv support
use_venv=1
if [[ $venv_dir == "-" ]]; then   use_venv=0; fi
# Set defaults
# Install directory without trailing slash
if [[ -z "${install_dir}" ]]; then     install_dir="$SCRIPT_DIR"; fi
# Name of the subdirectory (defaults to stable-diffusion-webui)
if [[ -z "${clone_dir}" ]]; then     clone_dir="stable-diffusion-webui"; fi
# python3 executable
if [[ -z "${python_cmd}" ]]; then     python_cmd="python3"; fi
# git executable
if [[ -z "${GIT}" ]]; then     export GIT="git"; else     export GIT_PYTHON_GIT_EXECUTABLE="${GIT}"; fi
# python3 venv without trailing slash (defaults to ${install_dir}/${clone_dir}/venv)
if [[ -z "${venv_dir}" ]] && [[ $use_venv -eq 1 ]]; then     venv_dir="venv"; fi
if [[ -z "${LAUNCH_SCRIPT}" ]]; then     LAUNCH_SCRIPT="launch.py"; fi
# this script cannot be run as root by default
can_run_as_root=0
# read any command line flags to the webui.sh script
while getopts "f" flag > /dev/null 2>&1; do     case ${flag} in         f) can_run_as_root=1;;         *) break;;     esac; done
# Disable sentry logging
export ERROR_REPORTING=FALSE
# Do not reinstall existing pip packages on Debian/Ubuntu
export PIP_IGNORE_INSTALLED=0
# Pretty print
delimiter="################################################################"
printf "\n%s\n" "${delimiter}"
printf "\e[1m\e[32mInstall script for stable-diffusion + Web UI\n"
printf "\e[1m\e[34mTested on Debian 11 (Bullseye), Fedora 34+ and openSUSE Leap 15.4 or newer.\e[0m"
printf "\n%s\n" "${delimiter}"
# Do not run as root
if [[ $(id -u) -eq 0 && can_run_as_root -eq 0 ]]; then     printf "\n%s\n" "${delimiter}";     printf "\e[1m\e[31mERROR: This script must not be launched as root, aborting...\e[0m";     printf "\n%s\n" "${delimiter}";     exit 1; else     printf "\n%s\n" "${delimiter}";     printf "Running on \e[1m\e[32m%s\e[0m user" "$(whoami)";     printf "\n%s\n" "${delimiter}"; fi
if [[ $(getconf LONG_BIT) = 32 ]]; then     printf "\n%s\n" "${delimiter}";     printf "\e[1m\e[31mERROR: Unsupported Running on a 32bit OS\e[0m";     printf "\n%s\n" "${delimiter}";     exit 1; fi
if [[ -d "$SCRIPT_DIR/.git" ]]; then     printf "\n%s\n" "${delimiter}";     printf "Repo already cloned, using it as install directory";     printf "\n%s\n" "${delimiter}";     install_dir="${SCRIPT_DIR}/../";     clone_dir="${SCRIPT_DIR##*/}"; fi
# Check prerequisites
gpu_info=$(lspci 2>/dev/null | grep -E "VGA|Display")
case "$gpu_info" in     *"Navi 1"*)         export HSA_OVERRIDE_GFX_VERSION=10.3.0;         if [[ -z "${TORCH_COMMAND}" ]];         then             pyv="$(${python_cmd} -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]:02d}")')"
            if [[ $pyv == "3.8" ]];             then                 export TORCH_COMMAND="pip install https://download.pytorch.org/whl/nightly/rocm5.2/torch-2.0.0.dev20230209%2Brocm5.2-cp38-cp38-linux_x86_64.whl https://download.pytorch.org/whl/nightly/rocm5.2/torchvision-0.15.0.dev20230209%2Brocm5.2-cp38-cp38-linux_x86_64.whl";             elif [[ $pyv == "3.9" ]];             then                 export TORCH_COMMAND="pip install https://download.pytorch.org/whl/nightly/rocm5.2/torch-2.0.0.dev20230209%2Brocm5.2-cp39-cp39-linux_x86_64.whl https://download.pytorch.org/whl/nightly/rocm5.2/torchvision-0.15.0.dev20230209%2Brocm5.2-cp39-cp39-linux_x86_64.whl";             elif [[ $pyv == "3.10" ]];             then                 export TORCH_COMMAND="pip install https://download.pytorch.org/whl/nightly/rocm5.2/torch-2.0.0.dev20230209%2Brocm5.2-cp310-cp310-linux_x86_64.whl https://download.pytorch.org/whl/nightly/rocm5.2/torchvision-0.15.0.dev20230209%2Brocm5.2-cp310-cp310-linux_x86_64.whl";             else                 printf "\e[1m\e[31mERROR: RX 5000 series GPUs python version must be between 3.8 and 3.10, aborting...\e[0m";                 exit 1;             fi;         fi;     ;;     *"Navi 2"*) export HSA_OVERRIDE_GFX_VERSION=10.3.0;     ;;     *"Navi 3"*) [[ -z "${TORCH_COMMAND}" ]] &&          export TORCH_COMMAND="pip install torch torchvision --index-url https://download.pytorch.org/whl/nightly/rocm5.7";     ;;     *"Renoir"*) export HSA_OVERRIDE_GFX_VERSION=9.0.0;         printf "\n%s\n" "${delimiter}";         printf "Experimental support for Renoir: make sure to have at least 4GB of VRAM and 10GB of RAM or enable cpu mode: --use-cpu all --no-half";         printf "\n%s\n" "${delimiter}";     ;;     *)     ;; esac
if ! echo "$gpu_info" | grep -q "NVIDIA"; then     if echo "$gpu_info" | grep -q "AMD" && [[ -z "${TORCH_COMMAND}" ]];     then 	      export TORCH_COMMAND="pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7";     elif npu-smi info 2>/dev/null;     then         export TORCH_COMMAND="pip install torch==2.1.0 torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu; pip install torch_npu==2.1.0";     fi; fi
for preq in "${GIT}" "${python_cmd}"; do     if ! hash "${preq}" &>/dev/null;     then         printf "\n%s\n" "${delimiter}";         printf "\e[1m\e[31mERROR: %s is not installed, aborting...\e[0m" "${preq}";         printf "\n%s\n" "${delimiter}";         exit 1;     fi; done
if [[ $use_venv -eq 1 ]] && ! "${python_cmd}" -c "import venv" &>/dev/null; then     printf "\n%s\n" "${delimiter}";     printf "\e[1m\e[31mERROR: python3-venv is not installed, aborting...\e[0m";     printf "\n%s\n" "${delimiter}";     exit 1; fi
#!/usr/bin/env bash
#################################################
# Please do not make any changes to this file,  #
# change the variables in webui-user.sh instead #
#################################################
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# If run from macOS, load defaults from webui-macos-env.sh
if [[ "$OSTYPE" == "darwin"* ]]; then     if [[ -f "$SCRIPT_DIR"/webui-macos-env.sh ]];         then         source "$SCRIPT_DIR"/webui-macos-env.sh;     fi; fi
# Read variables from webui-user.sh
# shellcheck source=/dev/null
if [[ -f "$SCRIPT_DIR"/webui-user.sh ]]; then     source "$SCRIPT_DIR"/webui-user.sh; fi
# If $venv_dir is "-", then disable venv support
use_venv=1
if [[ $venv_dir == "-" ]]; then   use_venv=0; fi
# Set defaults
# Install directory without trailing slash
if [[ -z "${install_dir}" ]]; then     install_dir="$SCRIPT_DIR"; fi
# Name of the subdirectory (defaults to stable-diffusion-webui)
if [[ -z "${clone_dir}" ]]; then     clone_dir="stable-diffusion-webui"; fi
# python3 executable
if [[ -z "${python_cmd}" ]]; then     python_cmd="python3"; fi
# git executable
if [[ -z "${GIT}" ]]; then     export GIT="git"; else     export GIT_PYTHON_GIT_EXECUTABLE="${GIT}"; fi
# python3 venv without trailing slash (defaults to ${install_dir}/${clone_dir}/venv)
if [[ -z "${venv_dir}" ]] && [[ $use_venv -eq 1 ]]; then     venv_dir="venv"; fi
if [[ -z "${LAUNCH_SCRIPT}" ]]; then     LAUNCH_SCRIPT="launch.py"; fi
# this script cannot be run as root by default
can_run_as_root=0
# read any command line flags to the webui.sh script
while getopts "f" flag > /dev/null 2>&1; do     case ${flag} in         f) can_run_as_root=1;;         *) break;;     esac; done
# Disable sentry logging
export ERROR_REPORTING=FALSE
# Do not reinstall existing pip packages on Debian/Ubuntu
export PIP_IGNORE_INSTALLED=0
# Pretty print
delimiter="################################################################"
printf "\n%s\n" "${delimiter}"
printf "\e[1m\e[32mInstall script for stable-diffusion + Web UI\n"
printf "\e[1m\e[34mTested on Debian 11 (Bullseye), Fedora 34+ and openSUSE Leap 15.4 or newer.\e[0m"
printf "\n%s\n" "${delimiter}"
# Do not run as root
if [[ $(id -u) -eq 0 && can_run_as_root -eq 0 ]]; then     printf "\n%s\n" "${delimiter}";     printf "\e[1m\e[31mERROR: This script must not be launched as root, aborting...\e[0m";     printf "\n%s\n" "${delimiter}";     exit 1; else     printf "\n%s\n" "${delimiter}";     printf "Running on \e[1m\e[32m%s\e[0m user" "$(whoami)";     printf "\n%s\n" "${delimiter}"; fi
if [[ $(getconf LONG_BIT) = 32 ]]; then     printf "\n%s\n" "${delimiter}";     printf "\e[1m\e[31mERROR: Unsupported Running on a 32bit OS\e[0m";     printf "\n%s\n" "${delimiter}";     exit 1; fi
if [[ -d "$SCRIPT_DIR/.git" ]]; then     printf "\n%s\n" "${delimiter}";     printf "Repo already cloned, using it as install directory";     printf "\n%s\n" "${delimiter}";     install_dir="${SCRIPT_DIR}/../";     clone_dir="${SCRIPT_DIR##*/}"; fi
# Check prerequisites
gpu_info=$(lspci 2>/dev/null | grep -E "VGA|Display")
case "$gpu_info" in     *"Navi 1"*)         export HSA_OVERRIDE_GFX_VERSION=10.3.0;         if [[ -z "${TORCH_COMMAND}" ]];         then             pyv="$(${python_cmd} -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]:02d}")')"
            if [[ $pyv == "3.8" ]];             then                 export TORCH_COMMAND="pip install https://download.pytorch.org/whl/nightly/rocm5.2/torch-2.0.0.dev20230209%2Brocm5.2-cp38-cp38-linux_x86_64.whl https://download.pytorch.org/whl/nightly/rocm5.2/torchvision-0.15.0.dev20230209%2Brocm5.2-cp38-cp38-linux_x86_64.whl";             elif [[ $pyv == "3.9" ]];             then                 export TORCH_COMMAND="pip install https://download.pytorch.org/whl/nightly/rocm5.2/torch-2.0.0.dev20230209%2Brocm5.2-cp39-cp39-linux_x86_64.whl https://download.pytorch.org/whl/nightly/rocm5.2/torchvision-0.15.0.dev20230209%2Brocm5.2-cp39-cp39-linux_x86_64.whl";             elif [[ $pyv == "3.10" ]];             then                 export TORCH_COMMAND="pip install https://download.pytorch.org/whl/nightly/rocm5.2/torch-2.0.0.dev20230209%2Brocm5.2-cp310-cp310-linux_x86_64.whl https://download.pytorch.org/whl/nightly/rocm5.2/torchvision-0.15.0.dev20230209%2Brocm5.2-cp310-cp310-linux_x86_64.whl";             else                 printf "\e[1m\e[31mERROR: RX 5000 series GPUs python version must be between 3.8 and 3.10, aborting...\e[0m";                 exit 1;             fi;         fi;     ;;     *"Navi 2"*) export HSA_OVERRIDE_GFX_VERSION=10.3.0;     ;;     *"Navi 3"*) [[ -z "${TORCH_COMMAND}" ]] &&          export TORCH_COMMAND="pip install torch torchvision --index-url https://download.pytorch.org/whl/nightly/rocm5.7";     ;;     *"Renoir"*) export HSA_OVERRIDE_GFX_VERSION=9.0.0;         printf "\n%s\n" "${delimiter}";         printf "Experimental support for Renoir: make sure to have at least 4GB of VRAM and 10GB of RAM or enable cpu mode: --use-cpu all --no-half";         printf "\n%s\n" "${delimiter}";     ;;     *)     ;; esac
if ! echo "$gpu_info" | grep -q "NVIDIA"; then     if echo "$gpu_info" | grep -q "AMD" && [[ -z "${TORCH_COMMAND}" ]];     then 	      export TORCH_COMMAND="pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7";     elif npu-smi info 2>/dev/null;     then         export TORCH_COMMAND="pip install torch==2.1.0 torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu; pip install torch_npu==2.1.0";     fi; fi
for preq in "${GIT}" "${python_cmd}"; do     if ! hash "${preq}" &>/dev/null;     then         printf "\n%s\n" "${delimiter}";         printf "\e[1m\e[31mERROR: %s is not installed, aborting...\e[0m" "${preq}";         printf "\n%s\n" "${delimiter}";         exit 1;     fi; done
if [[ $use_venv -eq 1 ]] && ! "${python_cmd}" -c "import venv" &>/dev/null; then     printf "\n%s\n" "${delimiter}";     printf "\e[1m\e[31mERROR: python3-venv is not installed, aborting...\e[0m";     printf "\n%s\n" "${delimiter}";     exit 1; fi
#!/bin/bash
#########################################################
# Uncomment and change the variables below to your need:#
#########################################################
# Install directory without trailing slash
#install_dir="/home/$(whoami)"
# Name of the subdirectory
#clone_dir="stable-diffusion-webui"
# Commandline arguments for webui.py, for example: export COMMANDLINE_ARGS="--medvram --opt-split-attention"
#export COMMANDLINE_ARGS=""
# python3 executable
#python_cmd="python3"
# git executable
#export GIT="git"
# python3 venv without trailing slash (defaults to ${install_dir}/${clone_dir}/venv)
#venv_dir="venv"
# script to launch to start the app
#export LAUNCH_SCRIPT="launch.py"
# install command for torch
#export TORCH_COMMAND="pip install torch==1.12.1+cu113 --extra-index-url https://download.pytorch.org/whl/cu113"
# Requirements file to use for stable-diffusion-webui
#export REQS_FILE="requirements_versions.txt"
# Fixed git repos
#export K_DIFFUSION_PACKAGE=""
#export GFPGAN_PACKAGE=""
# Fixed git commits
#export STABLE_DIFFUSION_COMMIT_HASH=""
#export TAMING_TRANSFORMERS_COMMIT_HASH=""
#export CODEFORMER_COMMIT_HASH=""
#export BLIP_COMMIT_HASH=""
# Uncomment to enable accelerated launch
#export ACCELERATE="True"
###########################################
#!/bin/bash
#########################################################
# Uncomment and change the variables below to your need:#
#########################################################
# Install directory without trailing slash
#install_dir="/home/$(whoami)"
# Name of the subdirectory
#clone_dir="stable-diffusion-webui"
# Commandline arguments for webui.py, for example: export COMMANDLINE_ARGS="--medvram --opt-split-attention"
#export COMMANDLINE_ARGS=""
# python3 executable
#python_cmd="python3"
# git executable
#export GIT="git"
# python3 venv without trailing slash (defaults to ${install_dir}/${clone_dir}/venv)
#venv_dir="venv"
# script to launch to start the app
#export LAUNCH_SCRIPT="launch.py"
# install command for torch
#export TORCH_COMMAND="pip install torch==1.12.1+cu113 --extra-index-url https://download.pytorch.org/whl/cu113"
# Requirements file to use for stable-diffusion-webui
#export REQS_FILE="requirements_versions.txt"
# Fixed git repos
#export K_DIFFUSION_PACKAGE=""
#export GFPGAN_PACKAGE=""
# Fixed git commits
#export STABLE_DIFFUSION_COMMIT_HASH=""
#export TAMING_TRANSFORMERS_COMMIT_HASH=""
#export CODEFORMER_COMMIT_HASH=""
#export BLIP_COMMIT_HASH=""
# Uncomment to enable accelerated launch
#export ACCELERATE="True"
###########################################
#!/usr/bin/env bash
#################################################
# Please do not make any changes to this file,  #
# change the variables in webui-user.sh instead #
#################################################
# If run from macOS, load defaults from webui-macos-env.sh
if [[ "$OSTYPE" == "darwin"* ]]; then     if [[ -f webui-macos-env.sh ]];         then         source ./webui-macos-env.sh;     fi; fi
# Read variables from webui-user.sh
# shellcheck source=/dev/null
if [[ -f webui-user.sh ]]; then     source ./webui-user.sh; fi
# Set defaults
# Install directory without trailing slash
if [[ -z "${install_dir}" ]]; then     install_dir="/home/$(whoami)"; fi
# Name of the subdirectory (defaults to stable-diffusion-webui)
if [[ -z "${clone_dir}" ]]; then     clone_dir="stable-diffusion-webui"; fi
# python3 executable
if [[ -z "${python_cmd}" ]]; then     python_cmd="python3"; fi
# git executable
if [[ -z "${GIT}" ]]; then     export GIT="git"; fi
# python3 venv without trailing slash (defaults to ${install_dir}/${clone_dir}/venv)
if [[ -z "${venv_dir}" ]]; then     venv_dir="venv"; fi
if [[ -z "${LAUNCH_SCRIPT}" ]]; then     LAUNCH_SCRIPT="launch.py"; fi
# this script cannot be run as root by default
can_run_as_root=0
# read any command line flags to the webui.sh script
while getopts "f" flag > /dev/null 2>&1; do     case ${flag} in         f) can_run_as_root=1;;         *) break;;     esac; done
# Disable sentry logging
export ERROR_REPORTING=FALSE
# Do not reinstall existing pip packages on Debian/Ubuntu
export PIP_IGNORE_INSTALLED=0
# Pretty print
delimiter="################################################################"
printf "\n%s\n" "${delimiter}"
printf "\e[1m\e[32mInstall script for stable-diffusion + Web UI\n"
printf "\e[1m\e[34mTested on Debian 11 (Bullseye)\e[0m"
printf "\n%s\n" "${delimiter}"
# Do not run as root
if [[ $(id -u) -eq 0 && can_run_as_root -eq 0 ]]; then     printf "\n%s\n" "${delimiter}";     printf "\e[1m\e[31mERROR: This script must not be launched as root, aborting...\e[0m";     printf "\n%s\n" "${delimiter}";     exit 1; else     printf "\n%s\n" "${delimiter}";     printf "Running on \e[1m\e[32m%s\e[0m user" "$(whoami)";     printf "\n%s\n" "${delimiter}"; fi
if [[ -d .git ]]; then     printf "\n%s\n" "${delimiter}";     printf "Repo already cloned, using it as install directory";     printf "\n%s\n" "${delimiter}";     install_dir="${PWD}/../";     clone_dir="${PWD##*/}"; fi
# Check prerequisites
gpu_info=$(lspci 2>/dev/null | grep VGA)
case "$gpu_info" in     *"Navi 1"*|*"Navi 2"*) export HSA_OVERRIDE_GFX_VERSION=10.3.0;     ;;     *"Renoir"*) export HSA_OVERRIDE_GFX_VERSION=9.0.0;         printf "\n%s\n" "${delimiter}";         printf "Experimental support for Renoir: make sure to have at least 4GB of VRAM and 10GB of RAM or enable cpu mode: --use-cpu all --no-half";         printf "\n%s\n" "${delimiter}";     ;;     *)      ;; esac
if echo "$gpu_info" | grep -q "AMD" && [[ -z "${TORCH_COMMAND}" ]]; then     export TORCH_COMMAND="pip install torch torchvision --extra-index-url https://download.pytorch.org/whl/rocm5.2"; fi  
for preq in "${GIT}" "${python_cmd}"; do     if ! hash "${preq}" &>/dev/null;     then         printf "\n%s\n" "${delimiter}";         printf "\e[1m\e[31mERROR: %s is not installed, aborting...\e[0m" "${preq}";         printf "\n%s\n" "${delimiter}";         exit 1;     fi; done
if ! "${python_cmd}" -c "import venv" &>/dev/null; then     printf "\n%s\n" "${delimiter}";     printf "\e[1m\e[31mERROR: python3-venv is not installed, aborting...\e[0m";     printf "\n%s\n" "${delimiter}";     exit 1; fi
