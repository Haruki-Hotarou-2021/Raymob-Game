#!/usr/bin/env bash
set -e

export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/25.2.9519653

PROJECT_DIR=$HOME/RayMob
BUILD_DIR=$PROJECT_DIR/android-build

ABIS=("armeabi-v7a" "arm64-v8a" "x86_64")

echo "📦 Limpando builds anteriores..."
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR

for ABI in "${ABIS[@]}"; do
    echo "🔨 Compilando para $ABI..."

        mkdir -p $BUILD_DIR/$ABI
            cd $BUILD_DIR/$ABI

                cmake $PROJECT_DIR \
                        -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
                                -DANDROID_ABI=$ABI \
                                        -DANDROID_PLATFORM=android-24 \
                                                -DCMAKE_BUILD_TYPE=Release \
                                                        -DUSE_LUAJIT=ON

                                                            cmake --build . -j$(nproc)

                                                                echo "📦 Gerando APK ($ABI)..."
                                                                    ./gradlew assembleRelease
                                                                    done

                                                                    # =========================
                                                                    # UNIVERSAL BUILD
                                                                    # =========================
                                                                    echo "🌍 Gerando AAB universal..."

                                                                    cd $PROJECT_DIR/android

                                                                    ./gradlew bundleRelease

                                                                    echo "📁 Builds geradas em:"
                                                                    echo "APKs: $BUILD_DIR/*/outputs/apk/release/"
                                                                    echo "AAB:  $PROJECT_DIR/android/app/build/outputs/bundle/release/"

                                                                    echo "✅ Build concluído!"