#!/bin/bash

# StreamKit Test Runner
# This script runs all tests and generates coverage reports

set -e

echo "🧪 Running StreamKit Tests..."
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    print_error "Package.swift not found. Please run this script from the StreamKit root directory."
    exit 1
fi

print_status "Building StreamKit..."

# Build the package
swift build

if [ $? -eq 0 ]; then
    print_status "Build successful!"
else
    print_error "Build failed!"
    exit 1
fi

print_status "Running unit tests..."

# Run tests with coverage
swift test --enable-code-coverage

if [ $? -eq 0 ]; then
    print_status "All tests passed!"
else
    print_error "Some tests failed!"
    exit 1
fi

# Generate coverage report if xcov is available
if command -v xcov &> /dev/null; then
    print_status "Generating coverage report..."
    xcov
else
    print_warning "xcov not found. Install with 'gem install xcov' for coverage reports."
fi

print_status "Running static analysis..."

# Run SwiftLint if available
if command -v swiftlint &> /dev/null; then
    swiftlint
    if [ $? -eq 0 ]; then
        print_status "Code style check passed!"
    else
        print_warning "Code style issues found. Check SwiftLint output above."
    fi
else
    print_warning "SwiftLint not found. Install with 'brew install swiftlint' for code style checking."
fi

echo ""
echo "🎉 Test suite completed!"
echo ""
echo "Next steps:"
echo "1. Test on physical device with ARKit"
echo "2. Test with real Relay server"
echo "3. Performance testing with continuous streaming"
echo ""
echo "Demo app: Open Demo/StreamKitDemo.xcodeproj in Xcode"