<#
.SYNOPSIS
  Build whisper.cpp's whisper-server with the Vulkan backend, RavensKeep's
  transcription engine (CPU, or AMD, Intel or NVIDIA GPUs).

.DESCRIPTION
  whisper.cpp publishes Windows builds for CPU and CUDA only, so the Vulkan one
  is built here. Needs:
    * git and CMake on PATH
    * Visual Studio (or its Build Tools) with "Desktop development with C++"
    * the Vulkan SDK (winget install KhronosGroup.VulkanSDK), which sets VULKAN_SDK;
      open a new terminal after installing it
  The result (whisper-server.exe and its DLLs, including ggml-vulkan.dll) is
  copied to -Dest, by default the "whispercpp" folder in RavensKeep's data folder,
  where Settings > AI > Transcription Model looks for it.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\build_whispercpp_vulkan.ps1

.EXAMPLE
  # What the release workflow in ravenskeep-app/releases runs (it keeps a copy of
  # this script; change both together): also zip the build for the app's Install button.
  tools\build_whispercpp_vulkan.ps1 -Dest out\whispercpp -Zip out\whispercpp-vulkan-win-x64.zip

  The build is portable: no optimisations for this PC's processor (GGML_NATIVE off)
  and the C++ runtime linked in, so it runs on any x64 Windows PC with a GPU driver
  and needs no Visual C++ Redistributable.
#>
param(
    [string]$Tag = "v1.9.5",
    [string]$Dest = "",
    [string]$Zip = "",
    # Kept short on purpose: the Vulkan shader generator nests deep folders, and
    # MSBuild's file tracker fails past Windows' 260-character path limit.
    [string]$Work = (Join-Path $env:LOCALAPPDATA "lrwc")
)
$ErrorActionPreference = "Stop"

if (-not $Dest) {
    $data = if ($env:RAVENSKEEP_HOME) { $env:RAVENSKEEP_HOME } elseif ($env:LORERAVEN_HOME) { $env:LORERAVEN_HOME } else { Join-Path $env:APPDATA "RavensKeep" }
    $Dest = Join-Path $data "whispercpp"
}
foreach ($tool in "git", "cmake") {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "$tool isn't on PATH." }
}
if (-not $env:VULKAN_SDK -or -not (Test-Path (Join-Path $env:VULKAN_SDK "Bin\glslc.exe"))) {
    throw ("The Vulkan SDK isn't installed (VULKAN_SDK is not set, or has no glslc). " +
           "Install it with: winget install KhronosGroup.VulkanSDK, then open a new terminal.")
}

$src = Join-Path $Work "w"
if (Test-Path $src) {
    git -C $src fetch --depth 1 origin tag $Tag
    git -C $src checkout --force $Tag
} else {
    New-Item -ItemType Directory -Force $Work | Out-Null
    git clone --depth 1 --branch $Tag https://github.com/ggml-org/whisper.cpp.git $src
}
if ($LASTEXITCODE) { throw "git failed." }

$build = Join-Path $src "b"
cmake -S $src -B $build -DGGML_VULKAN=ON -DBUILD_SHARED_LIBS=ON -DGGML_NATIVE=OFF `
    -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded `
    -DWHISPER_BUILD_EXAMPLES=ON -DWHISPER_BUILD_TESTS=OFF -DWHISPER_SDL2=OFF
if ($LASTEXITCODE) { throw "CMake configure failed." }
cmake --build $build --config Release --target whisper-server -j
if ($LASTEXITCODE) { throw "Build failed." }

$bin = Join-Path $build "bin\Release"
if (-not (Test-Path (Join-Path $bin "whisper-server.exe"))) { $bin = Join-Path $build "bin" }
if (-not (Test-Path (Join-Path $bin "ggml-vulkan.dll"))) {
    throw "The build has no ggml-vulkan.dll in $bin; the Vulkan backend wasn't built."
}
New-Item -ItemType Directory -Force $Dest | Out-Null
Copy-Item (Join-Path $bin "whisper-server.exe"), (Join-Path $bin "*.dll") $Dest -Force
# whisper.cpp and ggml are MIT licensed: the notice travels with the binaries.
Copy-Item (Join-Path $src "LICENSE") (Join-Path $Dest "LICENSE-whisper.cpp.txt") -Force
if ($Zip) {
    $Zip = [IO.Path]::GetFullPath($Zip)
    New-Item -ItemType Directory -Force (Split-Path -Parent $Zip) | Out-Null
    Remove-Item $Zip -ErrorAction SilentlyContinue
    Compress-Archive -Path (Join-Path $Dest "*") -DestinationPath $Zip
    $hash = (Get-FileHash $Zip -Algorithm SHA256).Hash.ToLower()
    Set-Content -Path "$Zip.sha256" -Value "$hash  $(Split-Path -Leaf $Zip)" -Encoding ascii
    Write-Host "Zipped to $Zip (sha256 $hash)"
}
Write-Host "whisper.cpp $Tag with Vulkan is in $Dest"
Write-Host "RavensKeep uses it from there: Settings > AI > Transcription Model shows the build it found."
