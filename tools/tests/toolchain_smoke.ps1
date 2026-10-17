# Smoke test for the portable toolchain: sets it up (downloads ~3 GB; CI does this on a Windows runner),
# then configures, compiles, links and runs a tiny program with the exact CMake arguments the game build
# uses. No game data involved.
#   powershell -File tools\tests\toolchain_smoke.ps1 [-Root C:\path\to\toolchain-dir]
param([string]$Root = "")
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
. (Join-Path $PSScriptRoot "..\desktop\toolchain.ps1")
if (-not $Root) { $Root = Join-Path ([IO.Path]::GetTempPath()) "rb2-toolchain-smoke" }
Use-PortableToolchain -Root $Root

$work = Join-Path ([IO.Path]::GetTempPath()) ("rb2-smoke-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force $work | Out-Null
Set-Content (Join-Path $work "CMakeLists.txt") @'
cmake_minimum_required(VERSION 3.25)
project(smoke LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 23)
add_executable(smoke main.cpp)
'@
Set-Content (Join-Path $work "main.cpp") @'
#include <windows.h>
#include <wrl/client.h>
#include <dxgi1_4.h>
#include <cstdio>
#include <cmath>
#include <string>
// Things the real build relies on: the MSVC STL, the Windows SDK, dxgi.lib, 128-bit division (compiler-rt).
int main() {
  Microsoft::WRL::ComPtr<IDXGIFactory4> factory;
  HRESULT hr = CreateDXGIFactory1(IID_PPV_ARGS(&factory));
  volatile unsigned __int128 big = (unsigned __int128)GetTickCount64() * 1000003u;
  volatile unsigned __int128 q = big / 7u;
  std::string s = "smoke ok, dxgi hr=" + std::to_string((long)hr) + " q=" + std::to_string((unsigned long long)q % 10) +
                  " round=" + std::to_string(std::nearbyint(2.5));
  std::puts(s.c_str());
  return 0;
}
'@
$cm = @(Get-PortableCMakeArgs)
& cmake -S $work -B (Join-Path $work "b") -G Ninja -DCMAKE_BUILD_TYPE=Release @cm
if ($LASTEXITCODE -ne 0) { throw "cmake configure failed" }
& cmake --build (Join-Path $work "b")
if ($LASTEXITCODE -ne 0) { throw "build failed" }
& (Join-Path $work "b\smoke.exe")
if ($LASTEXITCODE -ne 0) { throw "smoke.exe failed" }
Write-Host "portable toolchain OK"
