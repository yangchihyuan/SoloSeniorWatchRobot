#!/bin/bash
#Stop the script if any command fails and print the error message
set -Ee -o pipefail

#Nov 12, 2026
#Author: Chih-Yuan Yang

# Project-specific settings live outside this reusable installer. By default,
# load project.conf next to this script; PROJECT_CONFIG_FILE can override it.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_CONFIG_FILE="${PROJECT_CONFIG_FILE:-$SCRIPT_DIR/project.conf}"
if [[ ! -r "$PROJECT_CONFIG_FILE" ]]; then
  echo "Error: project configuration file not found: $PROJECT_CONFIG_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$PROJECT_CONFIG_FILE"
: "${PROJECT_NAME:?Error: PROJECT_NAME must be defined in $PROJECT_CONFIG_FILE}"

BUILD_DIR="$HOME/${PROJECT_NAME}_build"

# Check system RAM and swap size
# Check system RAM and swap size
if ! read -r RAMSize SwapSize < <(awk '
  /^MemTotal:/  { ram_kib = $2 }
  /^SwapTotal:/ { swap_kib = $2 }
  END {
    if (ram_kib == "" || swap_kib == "") {
      # Fallback check if swap_kib is missing
      if (ram_kib == "") exit 1
      swap_kib = 0
    }
    printf "%.2f %.2f\n", ram_kib / 1024 / 1024, swap_kib / 1024 / 1024
  }
' /proc/meminfo); then
  echo "Error: could not read the system RAM and swap sizes from /proc/meminfo." >&2
  exit 1
fi

# Sum them up
TotalSize=$(echo "$RAMSize + $SwapSize" | bc -l)

echo "Detected RAM:  ${RAMSize} GiB"
echo "Detected Swap: ${SwapSize} GiB"
echo "Total (RAM + Swap): ${TotalSize} GiB"

if (( $(echo "$TotalSize < 30" | bc -l) )); then
  echo "You had better have 30Gib to compile the $PROJECT_NAME program. Otherwise, some applications may be killed during this installation. If you don't have enough RAM, enlarge your swap."
  read -p "Do you want to enlarge your swap? [Y/n]" EnlargeSwap
  if [[ -z "$EnlargeSwap" || "$EnlargeSwap" =~ ^[Yy]$ ]]; then
    read -p "Enter the new swap size (GiB):" NewSwapSize
    # check whether the input is a valid number
    if ! [[ "$NewSwapSize" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      echo "Error: '$NewSwapSize' is not a valid number. Please try again."
      exit
    else
      # Find an active swap file. Swap partitions and zram devices cannot be
      # resized with these file operations.
      SWAP_FILE=$(swapon --show=NAME --noheadings | awk '$1 !~ /^\/dev\// && $1 ~ /^\// { print $1; exit }')
      if [[ -z "$SWAP_FILE" || ! -f "$SWAP_FILE" ]]; then
        echo "Error: no active swap file was found. Active swap devices are:" >&2
        swapon --show >&2
        exit 1
      fi

      sudo swapoff "$SWAP_FILE"
      sudo rm "$SWAP_FILE"
      sudo fallocate -l "${NewSwapSize}G" "$SWAP_FILE"
      sudo chmod 600 "$SWAP_FILE"
      sudo mkswap "$SWAP_FILE"
      sudo swapon "$SWAP_FILE"
      echo "Swap file $SWAP_FILE has been resized to ${NewSwapSize}G."
    fi
  fi
  read -p "Do you want to continue? [Y/n]" Continue
  if [[ -z "$Continue" || "$Continue" =~ ^[Yy]$ ]]; then
    echo "Continuing the installation..."
  else
    exit
  fi
fi


# 1. ask for sudo password
sudo -v

# 2. update the sudo timestamp (every 60 seconds)
# When the main script (PID) exits, this background loop will also exit automatically
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Next, place the installation commands that require a long time to execute...
echo "Starting long-running installation..."


source /etc/os-release
echo "Ubuntu version: $VERSION_ID"

read -p "What is your machine [PC/AGXOrin]" machine
if [ "$machine" = "AGXOrin" ]; then
  VRAMSize=64
elif [ "$machine" = "PC" ]; then
  VRAMSize=0
else
  echo "Error: '$machine' is not in the allowed list. Please try again."
  exit
fi

if [ "$machine" = "PC" ]; then
  read -r -p "Do you have an Nvidia GPU? [Y/n]" HaveNvidiaGPU
  if [[ -z "$HaveNvidiaGPU" || "$HaveNvidiaGPU" =~ ^[Yy]$ ]]; then
    read -r -p "Have you already installed the Nvidia GPU driver? [Y/n]" HaveNvidiaDriver
    if [[ "$HaveNvidiaDriver" =~ ^[Nn]$ ]]; then
      echo "You need to install the Nvidia GPU driver first. You can run this install.sh again after you install the Nvidia GPU driver."
      exit  #stop the installation script
    fi
    # Query the first NVIDIA GPU detected by the installed driver.
    if ! GPUModelName=$(nvidia-smi --query-gpu=name --format=csv,noheader | sed -n '1p'); then
      echo "Error: nvidia-smi could not detect an NVIDIA GPU. Check that the driver is installed."
      exit 1
    fi
    if ! VRAMMiB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | sed -n '1p'); then
      echo "Error: could not read the NVIDIA GPU's VRAM size from nvidia-smi."
      exit 1
    fi
    if [[ -z "$GPUModelName" || ! "$VRAMMiB" =~ ^[0-9]+$ ]]; then
      echo "Error: nvidia-smi returned incomplete GPU information."
      exit 1
    fi

    # Keep the numeric model (for example, 5080) for the CUDA selection below.
    if [[ "$GPUModelName" =~ ([0-9]{4}) ]]; then
      GPUModel="${BASH_REMATCH[1]}"
    else
      GPUModel="$GPUModelName"
    fi
    GPUModelFirstTwoDigits="${GPUModel:0:2}"
    VRAMSize=$(awk -v vram_mib="$VRAMMiB" 'BEGIN { printf "%d", (vram_mib / 1024) + 0.5 }')
    echo "Detected NVIDIA GPU: $GPUModelName (${VRAMSize} GiB VRAM)"
  else
    VRAMSize=0
  fi
fi

read -p "What is the robot model you use? [Zenbo/Kebbi/ZenboJrII]" RobotModel
#Check if the RobotModel is valid
allowed_robot_models=("Zenbo" "Kebbi" "ZenboJrII")
# Validate if the input is a valid string
if ! [[ "$RobotModel" =~ ^[A-Za-z]+$ ]]; then
  echo "Error: '$RobotModel' is not a valid string. Please try again."
  exit
fi
# Check if the input string is in the allowed_robot_models array
is_valid_robot_model=false
for allowed_robot_model in "${allowed_robot_models[@]}"; do
  if [ "$RobotModel" == "$allowed_robot_model" ]; then
    is_valid_robot_model=true
    break # Found a match, no need to check further
  fi
done

if ! [[ "$is_valid_robot_model" = true ]]; then
  echo "Error: '$RobotModel' is not in the allowed list. Please try again."
  exit
fi


#Install the compiler
sudo apt -y install build-essential     #Ubuntu 26.04.1 ships gcc15, which is not supported by nvcc 12.9
#sudo apt -y install gcc-13 g++-13		#gcc13 and gcc14 are supported by nvcc 12.9

#install git
sudo apt -y install git

#install zip
#Do I still need to install zip?
sudo apt -y install zip

#install libgtk-3-dev, which is used in OpenCV to show images
sudo apt update
sudo apt -y install libgtk-3-dev 

#create the working directory without deleting downloaded archives
mkdir -p "$BUILD_DIR"

#sudo apt -y install cmake

if [ "$machine" = "PC" ]; then
  # Ubuntu 22.04 cmake version is 3.22.1, which is not enough for emotiEfflib, which needs cmake 3.29 or above.
  sudo snap install cmake --classic   # version 4.2.2 will be installed
elif [ "$machine" = "AGXOrin" ]; then
  #Snap's cmake does not work on AGX Orin because the the AGX Orin Ubuntu does not a complete SELinux system.
  #The SELinux service is initialzed, but required componenets are missing, which leads to a failure of snap's sandbox.
  #sudo snap install cmake --classic   # version 4.2.2 will be installed
  cd "$BUILD_DIR"
  # Download the official Linux installer script
  wget https://github.com/Kitware/CMake/releases/download/v3.31.3/cmake-3.31.3-linux-aarch64.sh

  # Make it executable
  chmod +x cmake-3.31.3-linux-aarch64.sh

  # Run the installer (choose 'y' for license, 'y' for include subdirectory)
  sudo ./cmake-3.31.3-linux-aarch64.sh --prefix=/usr/local --skip-license
fi

#install OpenCV 4.11, which is required by MediaPipe
#install OpenCV 4.11 first, because it requires to key in sudo password again
cd "$BUILD_DIR"

InstalledOpenCVVersion=""
if command -v opencv_version >/dev/null 2>&1; then
  InstalledOpenCVVersion=$(opencv_version 2>/dev/null)
elif command -v pkg-config >/dev/null 2>&1 && pkg-config --exists opencv4; then
  InstalledOpenCVVersion=$(pkg-config --modversion opencv4 2>/dev/null)
fi

if [[ "$InstalledOpenCVVersion" =~ ^4\.11(\.|$) ]]; then
  echo "OpenCV $InstalledOpenCVVersion is already installed. Skipping the OpenCV build."
else
  if [[ -s opencv4.11.zip && -s opencv_contrib4.11.zip ]]; then
    read -r -p "OpenCV 4.11 archives are already downloaded. Skip downloading them? [Y/n] " SkipOpenCVDownload
    if [[ "$SkipOpenCVDownload" =~ ^[Nn]$ ]]; then
      wget -O opencv4.11.zip https://github.com/opencv/opencv/archive/refs/tags/4.11.0.zip
      wget -O opencv_contrib4.11.zip https://github.com/opencv/opencv_contrib/archive/refs/tags/4.11.0.zip
    fi
  else
    if [[ ! -s opencv4.11.zip ]]; then
      wget -O opencv4.11.zip https://github.com/opencv/opencv/archive/refs/tags/4.11.0.zip
    fi
    if [[ ! -s opencv_contrib4.11.zip ]]; then
      wget -O opencv_contrib4.11.zip https://github.com/opencv/opencv_contrib/archive/refs/tags/4.11.0.zip
    fi
  fi

  #the unzip option -n will skip existing files without prompting. This is useful if you want to avoid overwriting files that have already been extracted.
  unzip -n opencv4.11.zip
  unzip -n opencv_contrib4.11.zip
  cd opencv-4.11.0
  mkdir -p build && cd build
  sudo apt -y install libvtk9-dev       #vtk is required to compile opencv_vis module, which is required by EmotiEffLib
  #      -D WITH_VTK=ON \             #for emotiefflib
  #      -D BUILD_opencv_viz=ON       #for emotiefflib
  # Ubuntu 26.04.1 has ffmpeg version 8.0.1, which is not compatible with OpenCV 4.11. So, we need to disable ffmpeg in OpenCV 4.11.
  cmake  .. -DOPENCV_EXTRA_MODULES_PATH=../../opencv_contrib-4.11.0/modules \
        -D WITH_VTK=ON \
        -D BUILD_opencv_viz=ON \
        -DWITH_FFMPEG=OFF
  cmake --build . -j $(nproc)
  sudo make install
  #to config the loading directories to let /usr/local/lib works
  sudo ldconfig
fi


#install protobuf 3.19.1
#For Ubuntu 26.04.1, the default protobuf version is 3.21.12.
#I don't know if 3.21.12 is compatible with MediaPipe v0.10.22. So, I install protobuf 3.19.1.
cd "$BUILD_DIR"
wget -O protobuf-all-3.19.1.zip https://github.com/protocolbuffers/protobuf/releases/download/v3.19.1/protobuf-all-3.19.1.zip
unzip -n protobuf-all-3.19.1.zip
cd "$BUILD_DIR"/protobuf-3.19.1
./configure
#if I use "make -j $(nproc)", there is a peak of memory usage, which exceeds the RAM+SWAP size on some laptops.
make -j 10    #prevent memory peak usage
make check     # this command will generate a peak memory usage
sudo make install
sudo ldconfig # refresh shared library cache.



#install MediaPipe v0.10.22
cd "$BUILD_DIR"
if [ -d "mediapipe" ]; then
    rm -rf mediapipe
fi
git clone https://github.com/google-ai-edge/mediapipe.git
cd mediapipe
git checkout v0.10.22

#download our files
cd ~
if [ -d "$PROJECT_NAME" ]; then
    rm -rf "$PROJECT_NAME"
fi
git clone "https://github.com/yangchihyuan/${PROJECT_NAME}.git"
#copy our code to the mediapipe folder
cp -r ~/"$PROJECT_NAME"/Server/mediapipe_addition/* "$BUILD_DIR/mediapipe"

#Install bazelisk
cd "$BUILD_DIR"
#this command only works for amd64 architecture
if [ "$machine" = "PC" ]; then
  wget -O bazelisk-amd64.deb https://github.com/bazelbuild/bazelisk/releases/download/v1.25.0/bazelisk-amd64.deb
  sudo dpkg -i bazelisk-amd64.deb
elif [ "$machine" = "AGXOrin" ]; then
  wget -O bazelisk-arm64.deb https://github.com/bazelbuild/bazelisk/releases/download/v1.25.0/bazelisk-arm64.deb
  sudo dpkg -i bazelisk-arm64.deb
fi


#install OpenGL libraries, which will be used in MediaPipe for compiling GPU-related code.
#This is MediaPipe's requirement
sudo apt-get -y install mesa-common-dev libegl1-mesa-dev libgles2-mesa-dev

#build libmp library
cd "$BUILD_DIR/mediapipe"
#I need to manually change the sha256 value in mediapipe/WORKSPACE if the bazel build command reports a sha256 mismatch error for the AGX Orin case.
if [ "$machine" = "AGXOrin" ]; then
#    name = "KleidiAI",
#    sha256 = "8eeb81ff6bc7ab2de678c0c4a3d18b02c382a5122ac4edc26a3334c858531739",
  sed -i 's/ad37707084a6d4ff41be10cbe8540c75bea057ba79d0de6c367c1bfac6ba0852/8eeb81ff6bc7ab2de678c0c4a3d18b02c382a5122ac4edc26a3334c858531739/g' WORKSPACE
fi
#This command works on Ubuntu 24.04.
#bazel build -c opt mediapipe/examples/desktop/libmp:libmp_gpu.so
#Ubuntu 26.04.1 has Python 3.14, but MediaPipe v0.10.22 does not support Python 3.14 yet. So, we need to use Python 3.12 to build the libmp_gpu.so library.
#MediaPipe 0.10.36 starts to support Python 3.14. But I have not test the new version yet.
bazel build -c opt --repo_env=HERMETIC_PYTHON_VERSION=3.12 mediapipe/examples/desktop/libmp:libmp_gpu.so

#chekc if the bazel build is successful. Sometimes the repository is unavailable and bazel does not work.
DIR="bazel-out"

if [ -d "$DIR" ]; then
  echo "Directory $DIR exists. Mediapipe is built successfully. You can continue to install the Robot Nurse Helper."
else
  echo "Error: Directory $DIR does not exist. There is a problem with bazel build. Please check the error messages above and fix the problem. You can try to run the bazel build command again after fixing the problem."
  exit
fi

#Qt
#We use it to create our GUI
sudo apt -y install qt6-base-dev qt6-tools-dev qt6-multimedia-dev
#It will install Qt version 6.4.2.
#Hint
#The two commands to install Qt base and multimedia libraries allow you to compile this project. However, they do not install Qt Designer, a convenient tool to the GUI file mainwindow.ui. If you want to install Qt Designer, you need to use this command
sudo apt -y install qtcreator
#The Qt creator takes more than 1G disk space because it requires many libraries. Once installed, you can launch the program to open the mainwindow.ui file with Qt Designer.

#Qt Multimedia Plugins
#We need to install these plugins to let Qt Multimedia module play audio and video files properly
sudo apt install -y gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav

#PortAudio
#We use it to play voice on the server transmitted from the Android app and received from the robot's microphone. There is no package made for the Ubuntu system, and we need to compile it from downloaded source files, which are available on its GitHub page
cd "$BUILD_DIR"
if [ -d "portaudio" ]; then
    rm -rf portaudio
fi
git clone https://github.com/PortAudio/portaudio.git

#There is an instruction page teaching how to compile and install PortAudio (Link) However, as the page claims it is not reviewed, we modified its commands to

sudo apt-get -y install libasound2-dev
cd "$BUILD_DIR/portaudio"
./configure
make -j $(nproc)
sudo make install

#On some Linux systems, we need to reload the system to make the library visible.
sudo ldconfig

#whisper.cpp
#It is a voice-to-text library and we utilize it on our server-side program to quickly generate sentences spoken by an operator, which will be sent to the robot to speak out. There is no package make for the Ubuntu system, and we need to compile it from it source file downloaded from its GitHub repository

#Debug info 25/3/18,whisper.cpp v1.7.5 changes its install commands
cd "$BUILD_DIR"
if [ -d "whisper.cpp" ]; then
    rm -rf whisper.cpp
fi
git clone https://github.com/ggerganov/whisper.cpp.git
cd "$BUILD_DIR/whisper.cpp"
git checkout v1.7.5
#Download the tiny model first. If the user has enough VRAM, we will download a larger model later.
bash ./models/download-ggml-model.sh tiny
if ((VRAMSize==0)); then
  USE_EXTERNAL_GPU=OFF  #no GPU
  cmake -B build
  cmake --build build -j10 --config Release
else
  USE_EXTERNAL_GPU=ON  #Use external GPU
  if [ "$machine" = "PC" ]; then
    if [[ "$GPUModelFirstTwoDigits" == "50" ]]; then
      wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2604/x86_64/cuda-keyring_1.1-1_all.deb
      sudo dpkg -i cuda-keyring_1.1-1_all.deb
      sudo apt-get update
      sudo apt-get -y install cuda-toolkit-13-3
      echo 'export PATH=/usr/local/cuda-13.3/bin:$PATH' >> ~/.bashrc
      echo 'export LD_LIBRARY_PATH=/usr/local/cuda-13.3/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc

      CUDA_LINK="/usr/local/cuda"

      #If it is a upgrade from a previous CUDA version, we need to remove the existing symbolic link and create a new one.
      if [ -e "$CUDA_LINK" ] || [ -L "$CUDA_LINK" ]; then
        echo "Existing symbolic link: $(readlink "$CUDA_LINK")"
        sudo rm "$CUDA_LINK"
      fi
      sudo ln -s /usr/local/cuda-13.3 "$CUDA_LINK"

      # Select the CUDA 13.3 compiler in this installer shell. This matters
      # when /usr/bin/nvcc belongs to an older toolkit (for example 12.4).
      export CUDA_HOME=/usr/local/cuda-13.3
      export PATH="$CUDA_HOME/bin:$PATH"
      export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
      export CUDACXX="$CUDA_HOME/bin/nvcc"

      source ~/.bashrc
      "$CUDACXX" --version
    else
      #The Ubuntu 26.04.1 has nvidia-cuda-toolkit 12.5, which does not support RTX 5000 series GPUs and 
      sudo apt -y install nvidia-cuda-toolkit
    fi
  fi

  if ((VRAMSize==2)); then
    bash ./models/download-ggml-model.sh small
  else
    bash ./models/download-ggml-model.sh large-v3-turbo
  fi
  if [ "$machine" = "AGXOrin" ]; then
    #set up the ncvv path
    export CUDA_HOME=/usr/local/cuda
    export PATH="$CUDA_HOME/bin:$PATH"
    export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
    export CUDACXX="$CUDA_HOME/bin/nvcc"
  fi
  # Reconfigure with the selected compiler if this build directory was
  # previously configured with another nvcc.
  CUDA_CMAKE_ARGS=()
  if [[ -n "${CUDACXX:-}" ]]; then
    if [[ ! -x "$CUDACXX" ]]; then
      echo "Error: CUDA compiler is not executable: $CUDACXX" >&2
      exit 1
    fi
    echo "Using CUDA compiler: $CUDACXX"
    echo "Resolved CUDA compiler: $(readlink -f "$CUDACXX")"
    "$CUDACXX" --version
    CUDA_CMAKE_ARGS+=("-DCMAKE_CUDA_COMPILER:FILEPATH=$CUDACXX")
  fi
  export NVCC_APPEND_FLAGS='-allow-unsupported-compiler'
  cmake -S . -B build -DGGML_CUDA=1 "${CUDA_CMAKE_ARGS[@]}"
  cmake --build build -j10 --config Release    #Don't use -j, there are 20 cores in my laptop, which will cause a peak memory usage
fi

#onnx
cd "$BUILD_DIR"
if [ "$machine" = "PC" ]; then
  if ((VRAMSize > 0)); then
    wget -O onnxruntime-linux-x64-gpu-1.22.0.tgz https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-x64-gpu-1.22.0.tgz
    tar -xvzf onnxruntime-linux-x64-gpu-1.22.0.tgz
  else
    wget -O onnxruntime-linux-x64-1.22.0.tgz https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-x64-1.22.0.tgz
    tar -xvzf onnxruntime-linux-x64-1.22.0.tgz
  fi  
elif [ "$machine" = "AGXOrin" ]; then
  wget -O onnxruntime-linux-aarch64-1.22.0.tgz https://github.com/microsoft/onnxruntime/releases/download/v1.22.0/onnxruntime-linux-aarch64-1.22.0.tgz
  tar -xvzf onnxruntime-linux-aarch64-1.22.0.tgz
fi

#silero-vad
cd "$BUILD_DIR"
#we need to remove it first otherwise the git clone command will fail because the folder already exists.
if [ -d "silero-vad" ]; then
    rm -rf silero-vad
fi
git clone https://github.com/snakers4/silero-vad.git

#The EmotiEffLib uses a 3rd party library 3rdparty/xtl/CMakeLists.txt, which requires CMake 3.29 or above. Ubuntu 26.04.1 has CMake 4.2.2, which is enough for EmotiEffLib. But Ubuntu 24.04 has CMake 3.22.1, which is not enough for EmotiEffLib. So, we need to install CMake 4.2.2 on Ubuntu 24.04.
if [ "$VERSION_ID" == "26.04" ]; then
    echo "You are running Ubuntu 26.04. You have CMake 4.2.2, which is enough for EmotiEffLib. You can continue to install the $PROJECT_NAME."
elif [ "$VERSION_ID" == "24.04" ]; then
    sudo apt update
    sudo apt install software-properties-common wget apt-transport-https ca-certificates gnupg -y
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null
    # Example: Replace <UBUNTU_CODENAME> with your actual codename
    echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ noble main' | sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null
    # Update your package list
    sudo apt update
    sudo apt install cmake -y
    cmake --version   #It should be 4.1.2
else
    echo "You are running a different version: $VERSION_ID"
fi

#EmotiEffLib needs libopenblas-dev
sudo apt install libopenblas-dev -y

#EmotiEffLib
cd "$BUILD_DIR"
#we need to remove it first otherwise the git clone command will fail because the folder already exists.
if [ -d "EmotiEffLib" ]; then
    rm -rf EmotiEffLib
fi
git clone https://github.com/sb-ai-lab/EmotiEffLib.git
cd EmotiEffLib
git submodule update --init --recursive
cd emotieffcpplib
mkdir -p build
cd build
#I am not sure if this command works. Check it later.
#Their CMakeLists.txt file needs onnxruntime lib folder, but there is no lib64 folder.
#So, I create a symbolic link lib64 to lib
if [ "$machine" = "PC" ]; then
  if ((VRAMSize==0)); then
    cd "$BUILD_DIR/onnxruntime-linux-x64-1.22.0"
    ln -sfn lib lib64
    cd "$BUILD_DIR/EmotiEffLib/emotieffcpplib/build"
    cmake .. -DWITH_ONNX="$BUILD_DIR/onnxruntime-linux-x64-1.22.0" -DBUILD_SHARED_LIBS=ON
    make -j$(nproc)
    #The .so files are in "$BUILD_DIR/EmotiEffLib/emotieffcpplib/build/lib"
  else
    cd "$BUILD_DIR/onnxruntime-linux-x64-gpu-1.22.0"
    ln -sfn lib lib64
    cd "$BUILD_DIR/EmotiEffLib/emotieffcpplib/build"
    cmake .. -DWITH_ONNX="$BUILD_DIR/onnxruntime-linux-x64-gpu-1.22.0" -DBUILD_SHARED_LIBS=ON
    make -j$(nproc)
    #The .so files are in "$BUILD_DIR/EmotiEffLib/emotieffcpplib/build/lib"
  fi
elif [ "$machine" = "AGXOrin" ]; then
  cd "$BUILD_DIR/onnxruntime-linux-aarch64-1.22.0"
  ln -sfn lib lib64
  cd "$BUILD_DIR/EmotiEffLib/emotieffcpplib/build"
  cmake .. -DWITH_ONNX="$BUILD_DIR/onnxruntime-linux-aarch64-1.22.0" -DBUILD_SHARED_LIBS=ON
  make -j$(nproc)
  #The .so files are in "$BUILD_DIR/EmotiEffLib/emotieffcpplib/build/lib"
fi

#ollama
if [ "$machine" = "PC" ]; then
  sudo snap install curl
  cd "$BUILD_DIR/"
  #This command seems unnecenssary is from https://ollama.com/docs/installation
  curl.snap-acked        #ollama changed its installation script. There is a text explanation in the script. It only accepts Snap-curl and we need to use this command first to prevent a warning message
  curl -fsSL https://ollama.com/install.sh | sh
elif [ "$machine" = "AGXOrin" ]; then
  #There snap program on AGX Orin's Ubuntu is restricted, so we need to use wget
  wget -O- https://ollama.com/install.sh | sh
fi

#launch the service first
sudo systemctl enable --now ollama
ollama pull gemma3:1b
if [ "$VRAMSize" -ge 24 ]; then
  ollama pull gemma3:12b
elif [ "$VRAMSize" -ge 16 ]; then
  ollama pull gemma3:4b
fi


#ollama-hpp
cd "$BUILD_DIR"
if [ -d "ollama-hpp" ]; then
    rm -rf ollama-hpp
fi
git clone https://github.com/jmont-dev/ollama-hpp.git
cd "$BUILD_DIR/ollama-hpp"
git checkout v0.9.5
#2026/10/24. The latest version is still 0.9.7.
#The ollama.hpp vesion 0.9.7 has a conclict with GCC 13 std::hash (GCC is the default compiler package on Ubuntu 24.04).
#The old verion 0.9.5 does not have this problem because it does not use std::hash. So I use the old version 0.9.5 to prevent the compilation error.
#However, the 0.9.5 version is incompatible with the latest version of cpp-httplib 0.30.0.
#Apply patch to fix compilation with newer cpp-httplib (using sed to avoid patch whitespace issues)
sed -i 's|this->cli->Post("/api/generate", request_string, "application/json", stream_callback)|this->cli->Post("/api/generate", request_string.size(), [\&](size_t offset, size_t length, httplib::DataSink \&sink) { size_t chunk_len = length; size_t remaining = request_string.size() - offset; if (chunk_len > remaining) chunk_len = remaining; sink.write(request_string.data() + offset, chunk_len); return true; }, "application/json", stream_callback, [](uint64_t, uint64_t){ return true; })|' include/ollama.hpp
sed -i 's|this->cli->Post("/api/chat", request_string, "application/json", stream_callback)|this->cli->Post("/api/chat", request_string.size(), [\&](size_t offset, size_t length, httplib::DataSink \&sink) { size_t chunk_len = length; size_t remaining = request_string.size() - offset; if (chunk_len > remaining) chunk_len = remaining; sink.write(request_string.data() + offset, chunk_len); return true; }, "application/json", stream_callback, [](uint64_t, uint64_t){ return true; })|' include/ollama.hpp

#dlib library for face recognition
#The precompiled libdlib-dev does not work. It enables the DLIB_NO_GUI_SUPPORT
#sudo apt -y install libdlib-dev       #Ubuntu 24.04 has dlib version 19.24.0-1 available in its repository
#cd "$BUILD_DIR/"
#This command will go wrong in the future because new versions will changes its download URL
#curl https://dlib.net/files/dlib-20.0.tar.bz2 --output dlib-20.0.tar.bz2
#wget -O dlib-20.0.tar.bz2 https://dlib.net/files/dlib-20.0.tar.bz2
#tar -xjvf dlib-20.0.tar.bz2

#InspireFace (The library has not been tested on AGX Orin, but it should work because it is based on OpenCV and ONNX Runtime, which are both tested on AGX Orin.
#I need to test it on AGX Orin later. If there is a problem, I will try to fix it and update the code.
#if [ "$machine" = "PC" ]; then
  cd "$BUILD_DIR/"
  if [ -d "InspireFace" ]; then
      rm -rf InspireFace
  fi
  git clone https://github.com/HyperInspire/InspireFace.git
  cd InspireFace
  git checkout v1.2.3
  # Must enter this directory
  # Clone the repository and pull submodules
  git clone --recurse-submodules https://github.com/tunmx/inspireface-3rdparty.git 3rdparty

  # Download lightweight resource files for mobile device
  bash command/download_models_general.sh Pikachu
  # Download resource files for mobile device or PC/server
  bash command/download_models_general.sh Megatron
  # Download resource files for RV1109
  bash command/download_models_general.sh Gundam_RV1109
  # Download resource files for RV1106
  bash command/download_models_general.sh Gundam_RV1106
  # Download resource files for RK356X
  bash command/download_models_general.sh Gundam_RK356X
  # Download resource files for RK3588
  bash command/download_models_general.sh Gundam_RK3588
  # Download resource files for NVIDIA-GPU Device(TensorRT)
  bash command/download_models_general.sh Megatron_TRT

  # Download all model files
  bash command/download_models_general.sh

  # Execute the local compilation script
  bash command/build.sh
#fi

#cpp-httplib
cd "$BUILD_DIR"
if [ -d "cpp-httplib" ]; then
    rm -rf cpp-httplib
fi
git clone https://github.com/yhirose/cpp-httplib.git
cd cpp-httplib
git checkout v0.34.0

#Install ROS 2 lyrical.
# 1. Enable the Ubuntu Universe repository
sudo apt install software-properties-common -y
# The "universe" repository, which contains thousands of free, open-source software packages maintained by the Linux community rather than Canonical
sudo add-apt-repository -y universe

# 2. Download and add the official ROS 2 GPG key
sudo apt update && sudo apt install curl -y
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg

# 3. Add the ROS 2 repository to your sources list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

# 4. Update your package lists to recognize the newly added repository
sudo apt update

# 5. Install the ROS 2 desktop package
sudo apt install ros-lyrical-desktop -y
# Add the string if the string does not exist in the file. If the string exists, skip it.
grep -qxF "source /opt/ros/lyrical/setup.bash" ~/.bashrc || echo "source /opt/ros/lyrical/setup.bash" >> ~/.bashrc

#For ROS 2 node developers, we need the colcon build system
sudo apt install python3-colcon-common-extensions build-essential -y


#Do I still need to install the nvidia-power-management.conf file? I need to test it later.
#copy the file to prevent Nvidia GPU from being unavailable after laptop suspends
#Does this problem remain in Ubuntu 26.04? I need to test it later.
#if [ "$machine" = "PC" ] && [[ "$GPUModel" == "3050laptop" || "$GPUModel" == "4070laptop" ]]; then
#  sudo cp ~/$PROJECT_NAME/Server/nvidia-power-management.conf /etc/modprobe.d/
#  sudo update-initramfs -u
#fi

#Dowload media files from the internet
cd "$BUILD_DIR"
#wget --no-check-certificate 'https://docs.google.com/uc?export=download&id=1n5GuS6kqABCq5hGLOToFV_11V9mmEHZR' -O $PROJECT_NAME.zip
#for large files (>100MB), Google Drive will block the download and ask for a confirmation. Press F12 in your browser to download the file. In the Network tab, you will see the authentic URL.
#This link fails; why?
#wget --no-check-certificate 'https://drive.usercontent.google.com/download?id=1zVMH3INErwSuXJ1TF2gfPe2O0HVLu381&export=download&authuser=0&confirm=t&uuid=d4298704-bde8-444d-9ca4-0e36402c1e1f&at=APcXIO3sT6c9dZSljEclJVnWV_OW%3A1770877164167' -O ECICR_MediaFiles.zip
#unzip ECICR_MediaFiles.zip -d ECICR_MediaFiles
#cp -r ECICR_MediaFiles/$PROJECT_NAME/* ~/$PROJECT_NAME


#for playing video and audio in Qt Multimedia
#Ubuntu 26.04 removed the GTK2 package libcanberra-gtk-module
if [ "$VERSION_ID" == "26.04" ]; then
  sudo apt install -y libcanberra-gtk3-module   #for system sound support in Qt Multimedia
elif [ "$VERSION_ID" == "24.04" ]; then
  sudo apt install -y libcanberra-gtk-module libcanberra-gtk3-module   #for system sound support in Qt Multimedia
else
  if [ "$machine" = "AGXOrin" ]; then
    sudo apt install -y gstreamer1.0-tools gstreamer1.0-nice gstreamer1.0-qt5 gstreamer1.0-plugins-base
    sudo apt install -y gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly
    sudo apt install -y gstreamer1.0-libav
  fi 
fi

# Install the desktop file to let users launch the program by clicking the icon
# Copy the icon file to /usr/share/pixmaps, which is a standard directory for storing icons in Linux systems. This allows the system to find and display the icon properly when you launch the program from the application menu.
# We no longer need the program because it has been moved to the ROS 2 system.
sudo cp ~/"$PROJECT_NAME/Server/$PROJECT_NAME.png" /usr/share/pixmaps/"$PROJECT_NAME.png"
mkdir -p ~/.local/share/applications/

# Replace the @SERVER_DIR@ in ${PROJECT_NAME}.desktop with the actual path of the Server directory, and copy it to ~/.local/share/applications/
sed "s|@SERVER_DIR@|$HOME/$PROJECT_NAME/Server|g" \
  "$HOME/$PROJECT_NAME/Server/${PROJECT_NAME}.desktop" \
  > ~/.local/share/applications/"${PROJECT_NAME}.desktop"

#update desktop database
update-desktop-database ~/.local/share/applications/

# You need to log out and log in again for the desktop file to work. After that, you can launch the program by clicking the "Robot Nurse Helper" icon on your desktop or in the application menu.

#Yolov11-pose needs CuDNN to run its ONNX file. It only needs to be installed on the PC. The AGX Orin has its own GPU acceleration library compatible with CuDNN, so we don't need to install CuDNN on the AGX Orin.
#I need to update here because we no longer use Ubuntu 24.04. The keyring is different.
#I have not figured it out.
if [ "$machine" = "PC" ]; then
  cd "$BUILD_DIR"
  # Download Ubuntu 24.04 specific keyring
  # I did it already. I don't need to do it again
  # wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
  # Install keyring
  # sudo dpkg -i cuda-keyring_1.1-1_all.deb
  # update package list
  # sudo apt-get update
  # install runtime library for YOLOv11-pose

  #Here is a problem. If my PC has no GPU. How do I run CuDNN?
  if [ "$HaveNvidiaGPU" = "y" ] || [ "$HaveNvidiaGPU" = "Y" ]; then
    sudo apt-get install libcudnn9-cuda-12
    sudo ldconfig
    ls -l /usr/lib/x86_64-linux-gnu/libcudnn.so.9
  fi
fi

#For the audio_video_receiver program, we need to install python3-protobuf to let the program run properly. The protobuf version installed by "sudo apt install libprotobuf-dev" is 3.21.12, which is not compatible with the protobuf version used by the audio_video_receiver program. So, we need to install python3-protobuf to let the program run properly.
sudo apt install python3-protobuf

# Build the ROS 2 workspace
if [ -f /opt/ros/lyrical/setup.bash ]; then
  # The .bashrc entry does not affect this already-running installer shell.
  source /opt/ros/lyrical/setup.bash
else
  echo "Error: ROS 2 Lyrical is not installed at /opt/ros/lyrical."
  exit 1
fi
cd ~/"$PROJECT_NAME/ros2_ws"
colcon build --symlink-install \
  --packages-select audio_video_receiver my_robot_bringup

#Only the server_gui package needs to be built with the RobotModel argument. The other packages do not need this argument.
colcon build --symlink-install \
  --packages-select server_gui \
  --cmake-args \
    -DROBOT_MODEL="$RobotModel"

#create a symbolic link of MediaPipe's runtime resources for the server_gui node of the ROS 2 system
#MediaPipe ver 0.10.22 have some text files missing in the execution directory. Thus, I need manually copy them.
#MediaPipe ver 0.10.22 was released on Mar 2025. Should I update it?
#if [ -d "temp" ]; then
#    rm -rf temp
#fi
#mkdir -p temp
#cp -r "$BUILD_DIR/mediapipe/bazel-bin/mediapipe/examples/desktop/libmp/libmp_gpu.so.runfiles/mediapipe/mediapipe" temp
# This file mediapipe/modules/hand_landmark/handedness.txt is required to run holistic tracking
#find "$BUILD_DIR/mediapipe/mediapipe" -type f \( -name "*.txt" \) -exec cp --parents {} temp \;
#cp -r temp/home/$USER/mediapipe/mediapipe .
#rm -rf temp
source /opt/ros/lyrical/setup.bash
source $HOME/$PROJECT_NAME/ros2_ws/install/setup.bash

bazel_bin="$BUILD_DIR/mediapipe/bazel-bin"
resources="$bazel_bin/mediapipe/examples/desktop/libmp/libmp_gpu.so.runfiles/mediapipe/mediapipe"
#Queries the ROS 2 environment for the installation prefix of the server_gui package.
share="$(ros2 pkg prefix server_gui)/share/server_gui"

#create the symbolic link to the MediaPipe resources in the share directory of the server_gui package. This allows the server_gui node to access the necessary MediaPipe resources at runtime.
ln -sfn "$resources" "$share/mediapipe"


##############################
# Install AnythingLLM for RAG
##############################
#The library is required by AnythingLLM, but missing in Ubuntu 22.04, 24.04, and 26.04.
sudo apt install libfuse2

cd "$BUILD_DIR"
# Download the installer script to wherever you want to run it from
curl -fsSL https://cdn.anythingllm.com/latest/installer.sh -o installer.sh
 
# Make the script executable
chmod +x installer.sh

export ANYTHING_LLM_INSTALL_DIR="$BUILD_DIR"
#sh install.sh 
# Run the script. Press Enter to accept the default "y" to answer the question.
echo "y" | ./installer.sh


##############################
#AnythingLLM Instructions
##############################
echo "Launch AnythingLLM, and do the following things:"
echo "1. Create a new workspace named 'cataract'."
echo "2. Upload the CataractRAG.txt to cataract workspace."
echo "3. Set the workspace LLM provider as Ollama, and set the model as gemma3:1b. If your machine has more than 16G VRAM, you can also set the model as gemma3:4b or gemma3:12b to let the RAG function have a better performance. But it will be slower to generate the first token because the model is larger."
echo "4. Set the System Prompt as the prompt in the AnythingLLM_Setting.txt"
echo "5. Go to the AnythingLLM setting/Tools/Developer API to create a new API key."
echo "6. Copy the API key and paste it in the Setting.json to use AnythingLLM's RAG function."
