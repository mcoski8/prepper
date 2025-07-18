#!/bin/bash

# Create XCFramework for Tantivy Mobile
# This bundles the static library for distribution

set -e

echo "Creating XCFramework for Tantivy Mobile..."

cd ../rust/tantivy-mobile

# Build if not already built
if [ ! -f "../../ios/Libraries/libtantivy_mobile.a" ]; then
    echo "Building iOS library first..."
    cd ../../scripts
    ./build-ios-lib.sh
    cd ../rust/tantivy-mobile
fi

# Create XCFramework
OUTPUT_DIR="../../ios/Frameworks"
mkdir -p $OUTPUT_DIR

echo "Creating XCFramework..."
xcodebuild -create-xcframework \
    -library ../../ios/Libraries/libtantivy_mobile.a \
    -headers . \
    -output $OUTPUT_DIR/TantivyMobile.xcframework

echo "XCFramework created at: $OUTPUT_DIR/TantivyMobile.xcframework"

# Create module map for Swift integration
MODULE_DIR="$OUTPUT_DIR/TantivyMobile.xcframework/ios-arm64/TantivyMobile.framework/Modules"
mkdir -p $MODULE_DIR

cat > $MODULE_DIR/module.modulemap << EOF
framework module TantivyMobile {
    umbrella header "tantivy_mobile.h"
    
    export *
    module * { export * }
}
EOF

echo "Module map created for Swift integration"