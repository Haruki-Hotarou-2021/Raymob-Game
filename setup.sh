#!/usr/bin/env bash

# Raymob CLI Installer
# Instala globalmente o CLI Raymob e configura auto-reload de ambiente.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLI_DIR="$HOME/.raymob-cli"
CLI_BIN="$CLI_DIR/bin"
CLI_LIB="$CLI_DIR/lib"

log_info() { echo -e "${BLUE}$*${NC}"; }
log_ok() { echo -e "${GREEN}$*${NC}"; }
log_warn() { echo -e "${YELLOW}$*${NC}"; }
log_err() { echo -e "${RED}$*${NC}"; }

detect_os() {
  case "${OSTYPE:-linux-gnu}" in
    linux-gnu*) echo "linux" ;;
    darwin*) echo "macos" ;;
    msys*|cygwin*) echo "windows" ;;
    *) echo "linux" ;;
  esac
}

install_system_deps() {
  local os="$1"
  log_info "📦 Instalando dependências do sistema (${os})..."

  if [[ "$os" == "linux" ]]; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
      bash curl wget unzip zip git ca-certificates \
      build-essential pkg-config cmake ninja-build \
      libx11-dev libxi-dev libxrandr-dev libxcursor-dev libxinerama-dev \
      libgl1-mesa-dev libglu1-mesa-dev libasound2-dev libudev-dev \
      libwayland-dev libxkbcommon-dev xorg-dev \
      openjdk-17-jdk
  else
    log_warn "⚠️ Instalação automática de dependências não implementada para ${os}."
  fi

  log_ok "✅ Dependências do sistema prontas."
}

install_global_cli() {
  mkdir -p "$CLI_BIN" "$CLI_LIB"

  cat > "$CLI_BIN/raymob" <<'CLI_MAIN_EOF'
#!/usr/bin/env bash
set -euo pipefail

CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$CLI_DIR/lib/raymob.sh"

cmd="${1:-help}"
case "$cmd" in
  setup)
    shift
    cmd_setup "$@"
    ;;
  build)
    shift
    cmd_build "$@"
    ;;
  run)
    shift || true
    cmd_run "$@"
    ;;
  doctor)
    shift || true
    cmd_doctor "$@"
    ;;
  help|-h|--help)
    show_help
    ;;
  *)
    echo "❌ Comando desconhecido: $cmd"
    show_help
    exit 1
    ;;
esac
CLI_MAIN_EOF

  chmod +x "$CLI_BIN/raymob"

  local shell_rc="$HOME/.bashrc"
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    shell_rc="$HOME/.zshrc"
  fi

  if [[ -f "$shell_rc" ]] && ! grep -q 'raymob-cli/bin' "$shell_rc"; then
    {
      echo ''
      echo '# Raymob CLI'
      echo 'export PATH="$HOME/.raymob-cli/bin:$PATH"'
      echo 'export RAYMOB_HOME="$HOME/.raymob-cli"'
      echo 'export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"'
    } >> "$shell_rc"
  fi

  export PATH="$CLI_BIN:$PATH"
  export RAYMOB_HOME="$CLI_DIR"
  hash -r

  log_ok "✅ CLI instalado em $CLI_BIN/raymob"
  log_ok "✅ Auto-reload aplicado na sessão atual (PATH atualizado)."
}

create_cli_library() {
  cat > "$CLI_LIB/raymob.sh" <<'RAYMOB_LIB_EOF'
#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

RAYMOB_VERSION="1.1"
DEFAULT_ANDROID_API="android-34"
DEFAULT_BUILD_TOOLS="34.0.0"
DEFAULT_NDK_VERSION="26.3.11579264"
DEFAULT_CMAKE_SDK_VERSION="3.22.1"

log_info() { echo -e "${BLUE}$*${NC}"; }
log_ok() { echo -e "${GREEN}$*${NC}"; }
log_warn() { echo -e "${YELLOW}$*${NC}"; }
log_err() { echo -e "${RED}$*${NC}"; }

show_help() {
  cat <<HELP_EOF
Raymob CLI v${RAYMOB_VERSION} - Raylib + LuaJIT

Comandos:
  raymob setup            🚀 Cria projeto e instala dependências (SDK/NDK/CMake)
  raymob build android    📱 Gera libs Android (arm64-v8a, armeabi-v7a, x86_64, x86)
  raymob build desktop    💻 Compila executável desktop
  raymob run              ▶️  Build + execução local
  raymob doctor           🩺 Verifica ferramentas instaladas
  raymob help             ❓ Ajuda

Uso:
  raymob <comando> [opções]
HELP_EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log_err "❌ Dependência ausente: $1"
    return 1
  }
}

detect_os() {
  case "${OSTYPE:-linux-gnu}" in
    linux-gnu*) echo "linux" ;;
    darwin*) echo "macos" ;;
    msys*|cygwin*) echo "windows" ;;
    *) echo "linux" ;;
  esac
}

setup_env() {
  export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
  export ANDROID_HOME="$ANDROID_SDK_ROOT"
  export PATH="$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"
  export NDK_VERSION="${RAYMOB_NDK_VERSION:-$DEFAULT_NDK_VERSION}"
  export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/$NDK_VERSION"
}

install_host_deps_linux() {
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    git wget curl unzip zip openjdk-17-jdk \
    build-essential pkg-config cmake ninja-build \
    libx11-dev libxi-dev libxrandr-dev libxcursor-dev libxinerama-dev \
    libgl1-mesa-dev libglu1-mesa-dev libasound2-dev libudev-dev
}

ensure_android_tooling() {
  setup_env

  mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"

  if [[ ! -x "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]]; then
    log_info "⬇️ Instalando Android Command-line Tools..."
    local tmp_zip
    tmp_zip="$(mktemp /tmp/cmdline-tools-XXXXXX.zip)"
    wget -q "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -O "$tmp_zip"
    rm -rf "$ANDROID_SDK_ROOT/cmdline-tools/latest"
    unzip -q "$tmp_zip" -d "$ANDROID_SDK_ROOT/cmdline-tools"
    mv "$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
    rm -f "$tmp_zip"
  fi

  yes | sdkmanager --licenses >/dev/null || true

  log_info "📦 Instalando SDK/NDK/CMake do Android..."
  sdkmanager \
    "platform-tools" \
    "platforms;${DEFAULT_ANDROID_API}" \
    "build-tools;${DEFAULT_BUILD_TOOLS}" \
    "cmake;${DEFAULT_CMAKE_SDK_VERSION}" \
    "ndk;${NDK_VERSION}"

  setup_env
}

create_project_scaffold() {
  mkdir -p raymob/{src,assets,build/{android,desktop},libs}

  if [[ ! -f raymob/src/main.c ]]; then
    cat > raymob/src/main.c <<'MAIN_C_EOF'
#include "raylib.h"
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

int main(void) {
    const int screenWidth = 800;
    const int screenHeight = 450;

    InitWindow(screenWidth, screenHeight, "Raymob - Lua Game");
    SetTargetFPS(60);

    lua_State *L = luaL_newstate();
    luaL_openlibs(L);

    if (luaL_dofile(L, "../assets/main.lua") != LUA_OK) {
        TraceLog(LOG_ERROR, "Lua Error: %s", lua_tostring(L, -1));
        lua_close(L);
        CloseWindow();
        return 1;
    }

    while (!WindowShouldClose()) {
        lua_getglobal(L, "update");
        lua_pcall(L, 0, 0, 0);

        BeginDrawing();
        ClearBackground(RAYWHITE);

        lua_getglobal(L, "draw");
        lua_pcall(L, 0, 0, 0);

        EndDrawing();
    }

    lua_close(L);
    CloseWindow();
    return 0;
}
MAIN_C_EOF
  fi

  if [[ ! -f raymob/assets/main.lua ]]; then
    cat > raymob/assets/main.lua <<'MAIN_LUA_EOF'
screenWidth = 800
screenHeight = 450

player = { x = 400, y = 225, speed = 220, w = 40, h = 40 }

function update()
    if IsKeyDown(KEY_LEFT) or IsKeyDown(KEY_A) then
        player.x = player.x - player.speed * GetFrameTime()
    end
    if IsKeyDown(KEY_RIGHT) or IsKeyDown(KEY_D) then
        player.x = player.x + player.speed * GetFrameTime()
    end
    if IsKeyDown(KEY_UP) or IsKeyDown(KEY_W) then
        player.y = player.y - player.speed * GetFrameTime()
    end
    if IsKeyDown(KEY_DOWN) or IsKeyDown(KEY_S) then
        player.y = player.y + player.speed * GetFrameTime()
    end

    player.x = math.max(0, math.min(screenWidth - player.w, player.x))
    player.y = math.max(0, math.min(screenHeight - player.h, player.y))
end

function draw()
    DrawText("Raymob Lua Template", 10, 10, 24, DARKBLUE)
    DrawText("WASD/Setas para mover", 10, 40, 18, GRAY)
    DrawRectangle(player.x, player.y, player.w, player.h, ORANGE)
    DrawText("FPS: " .. tostring(GetFPS()), 10, screenHeight - 30, 20, DARKGREEN)
end
MAIN_LUA_EOF
  fi

  if [[ ! -d raymob/libs/raylib ]]; then
    log_info "📥 Clonando raylib..."
    git clone --depth 1 https://github.com/raysan5/raylib.git raymob/libs/raylib
  fi

  if [[ ! -d raymob/libs/LuaJIT ]]; then
    log_info "📥 Clonando LuaJIT..."
    git clone --depth 1 https://github.com/LuaJIT/LuaJIT.git raymob/libs/LuaJIT
  fi

  cat > raymob/CMakeLists.txt <<'CMAKE_EOF'
cmake_minimum_required(VERSION 3.20)
project(raymob C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

add_subdirectory(libs/raylib)

if(ANDROID)
  if(NOT DEFINED LUAJIT_LIB OR NOT DEFINED LUAJIT_INC)
    message(FATAL_ERROR "Para Android, informe -DLUAJIT_LIB e -DLUAJIT_INC")
  endif()
endif()

if(NOT ANDROID)
  find_library(LUAJIT_LIB NAMES luajit-5.1 luajit)
  if(NOT LUAJIT_LIB)
    message(FATAL_ERROR "LuaJIT não encontrado. Rode: raymob setup")
  endif()
  set(LUAJIT_INC libs/LuaJIT/src)
endif()

add_executable(raymob src/main.c)
target_include_directories(raymob PRIVATE libs/raylib/src ${LUAJIT_INC})
target_link_libraries(raymob PRIVATE raylib ${LUAJIT_LIB} m)
CMAKE_EOF

  log_ok "✅ Projeto criado/atualizado em ./raymob"
}

build_luajit_host() {
  if ldconfig -p 2>/dev/null | grep -q 'libluajit'; then
    return 0
  fi

  log_info "🔧 Compilando LuaJIT para host..."
  pushd raymob/libs/LuaJIT >/dev/null
  make -j"$(nproc)" CFLAGS="-DLUAJIT_DISABLE_JIT=1"
  sudo make install
  popd >/dev/null
}

cmd_setup() {
  log_info "🚀 Preparando ambiente Raymob..."

  local os
  os="$(detect_os)"
  if [[ "$os" == "linux" ]]; then
    install_host_deps_linux
  else
    log_warn "⚠️ Setup automático de dependências host é focado em Linux."
  fi

  ensure_android_tooling
  create_project_scaffold
  build_luajit_host

  log_ok "🎉 Setup concluído!"
  log_info "Próximos passos:"
  echo "  cd raymob"
  echo "  raymob build desktop"
  echo "  raymob build android"
}

cmd_build_desktop() {
  require_cmd cmake
  require_cmd make

  [[ -d raymob ]] || { log_err "❌ Rode 'raymob setup' no diretório do projeto."; return 1; }

  log_info "💻 Build desktop iniciado..."
  mkdir -p raymob/build/desktop
  pushd raymob/build/desktop >/dev/null
  cmake ../.. -DCMAKE_BUILD_TYPE=Release
  cmake --build . -j"$(nproc)"
  popd >/dev/null

  log_ok "✅ Build desktop concluído: raymob/build/desktop/raymob"
}

cmd_build_android() {
  setup_env
  require_cmd cmake
  require_cmd sdkmanager

  [[ -d raymob ]] || { log_err "❌ Rode 'raymob setup' no diretório do projeto."; return 1; }
  [[ -f "$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" ]] || {
    log_err "❌ NDK não encontrado em $ANDROID_NDK_HOME"
    log_info "   Execute: raymob setup"
    return 1
  }

  local host_tag="linux-x86_64"
  local toolchain_bin="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/${host_tag}/bin"
  local abis=("arm64-v8a" "armeabi-v7a" "x86_64" "x86")
  local api_level=24
  local luajit_inc
  luajit_inc="$(realpath raymob/libs/LuaJIT/src)"

  log_info "📱 Build Android iniciado..."

  for abi in "${abis[@]}"; do
    local out="raymob/build/android/${abi}"
    local luajit_out="${out}/luajit"
    local target_triple=""
    case "$abi" in
      arm64-v8a) target_triple="aarch64-linux-android" ;;
      armeabi-v7a) target_triple="armv7a-linux-androideabi" ;;
      x86_64) target_triple="x86_64-linux-android" ;;
      x86) target_triple="i686-linux-android" ;;
    esac
    local cross_prefix="${toolchain_bin}/${target_triple}${api_level}-"
    mkdir -p "$out" "$luajit_out"

    log_info "🔧 Compilando LuaJIT para ${abi}..."
    pushd raymob/libs/LuaJIT >/dev/null
    make clean >/dev/null 2>&1 || true
    make -j"$(nproc)" \
      HOST_CC="gcc" \
      CROSS="${cross_prefix}" \
      TARGET_AR="${toolchain_bin}/llvm-ar rcus" \
      TARGET_STRIP="${toolchain_bin}/llvm-strip" \
      TARGET_SYS=Linux \
      BUILDMODE=static
    cp src/libluajit.a "${OLDPWD}/${luajit_out}/libluajit.a"
    popd >/dev/null

    local luajit_lib
    luajit_lib="$(realpath ${luajit_out}/libluajit.a)"

    pushd "$out" >/dev/null

    cmake ../../.. \
      -GNinja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
      -DANDROID_ABI="$abi" \
      -DANDROID_PLATFORM="android-${api_level}" \
      -DANDROID_STL="c++_static" \
      -DLUAJIT_LIB="${luajit_lib}" \
      -DLUAJIT_INC="${luajit_inc}"

    cmake --build . -j"$(nproc)"
    popd >/dev/null
    log_ok "✅ ABI ${abi} compilada"
  done

  log_ok "🎉 Build Android concluído em raymob/build/android/<abi>/"
}

cmd_run() {
  if [[ ! -x raymob/build/desktop/raymob ]]; then
    log_warn "🔨 Binário não encontrado. Gerando build desktop..."
    cmd_build_desktop
  fi

  pushd raymob/build/desktop >/dev/null
  ./raymob
  popd >/dev/null
}

cmd_build() {
  case "${1:-}" in
    android) cmd_build_android ;;
    desktop) cmd_build_desktop ;;
    *)
      log_err "Use: raymob build android|desktop"
      return 1
      ;;
  esac
}

cmd_doctor() {
  setup_env
  log_info "🩺 Raymob Doctor"

  local ok=0
  for cmd in git cmake make javac; do
    if command -v "$cmd" >/dev/null 2>&1; then
      log_ok "✅ $cmd: $(command -v "$cmd")"
    else
      log_err "❌ $cmd: ausente"
      ok=1
    fi
  done

  if [[ -x "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]]; then
    log_ok "✅ sdkmanager: $ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
  else
    log_err "❌ sdkmanager ausente"
    ok=1
  fi

  if [[ -f "$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" ]]; then
    log_ok "✅ NDK: $ANDROID_NDK_HOME"
  else
    log_err "❌ NDK ausente: $ANDROID_NDK_HOME"
    ok=1
  fi

  return "$ok"
}
RAYMOB_LIB_EOF

  chmod +x "$CLI_LIB/raymob.sh"
  log_ok "✅ Biblioteca do CLI criada."
}

main() {
  local os
  os="$(detect_os)"

  log_info "🚀 Raymob CLI Installer"
  log_info "OS detectado: $os"

  install_system_deps "$os"
  install_global_cli
  create_cli_library

  log_ok "🎉 Raymob CLI instalado com sucesso!"
  log_info "Teste agora: raymob setup"
  log_warn "Se abrir novo terminal não for possível, rode: source ~/.bashrc"
}

main "$@"
