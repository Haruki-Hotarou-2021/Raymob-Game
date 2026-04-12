#!/usr/bin/env bash
set -e

echo "📦 Atualizando sistema..."
sudo apt update && sudo apt upgrade -y

echo "🔧 Instalando dependências..."
sudo apt install -y \
    git cmake ninja-build build-essential \
        unzip wget curl openjdk-17-jdk \
            pkg-config libgl1-mesa-dev

            # =========================
            # ANDROID SDK + NDK
            # =========================
            export ANDROID_HOME=$HOME/Android/Sdk
            export ANDROID_SDK_ROOT=$ANDROID_HOME

            mkdir -p $ANDROID_HOME/cmdline-tools
            cd $ANDROID_HOME

            echo "⬇️ Baixando Android SDK..."
            wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O sdk.zip
            unzip sdk.zip -d cmdline-tools
            mv cmdline-tools/cmdline-tools cmdline-tools/latest

            export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH

            yes | sdkmanager --licenses

            sdkmanager \
                "platform-tools" \
                    "platforms;android-33" \
                        "build-tools;33.0.2" \
                            "ndk;25.2.9519653"

                            export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/25.2.9519653

                            # =========================
                            # LUAJIT
                            # =========================
                            cd $HOME
                            echo "⬇️ Baixando LuaJIT..."
                            git clone https://github.com/LuaJIT/LuaJIT.git
                            cd LuaJIT
                            make -j$(nproc)
                            sudo make install

                            export LUAJIT_LIB=/usr/local/lib
                            export LUAJIT_INC=/usr/local/include/luajit-2.1

                            # =========================
                            # RAYMOB
                            # =========================
                            cd $HOME
                            echo "⬇️ Clonando Raymob..."
                            git clone https://github.com/Bigfoot71/RayMob.git
                            cd RayMob

                            mkdir build && cd build

                            echo "⚙️ Configurando build com LuaJIT..."
                            cmake .. \
                                -DCMAKE_BUILD_TYPE=Release \
                                    -DUSE_LUAJIT=ON \
                                        -DLUA_INCLUDE_DIR=$LUAJIT_INC \
                                            -DLUA_LIBRARY=$LUAJIT_LIB/libluajit-5.1.so

                                            echo "🔨 Compilando Raymob..."
                                            cmake --build . -j$(nproc)

                                            echo "📁 Criando estrutura de assets..."
                                            mkdir -p $HOME/game/assets

                                            cat <<EOF > $HOME/game/assets/main.lua
                                            print("Hello from LuaJIT + Raymob 🚀")

                                            while true do
                                                -- loop básico
                                                end
                                                EOF

                                                echo "✅ Setup concluído!"