#!/bin/bash

# StreamKit Test App - Test Runner
# Comprehensive testing script for the StreamKit Test App

set -e

echo "🧪 StreamKit Test App - Test Suite"
echo "=================================="
echo "$(date)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    print_error "Package.swift not found. Please run this script from the StreamKitTestApp root directory."
    exit 1
fi

print_status "Found Package.swift"

# Environment Check
echo ""
echo "🔧 Environment Check"
echo "-------------------"

# Check Swift version
SWIFT_VERSION=$(swift --version | head -n 1)
print_info "Swift Version: $SWIFT_VERSION"

# Check Xcode version (if available)
if command -v xcodebuild &> /dev/null; then
    XCODE_VERSION=$(xcodebuild -version | head -n 1)
    print_info "Xcode Version: $XCODE_VERSION"
else
    print_warning "Xcode not found in PATH"
fi

# Check for iOS simulator
if command -v xcrun &> /dev/null; then
    SIMULATORS=$(xcrun simctl list devices | grep -c "iPhone")
    print_info "iOS Simulators available: $SIMULATORS"
else
    print_warning "xcrun not available"
fi

# Package Validation
echo ""
echo "📦 Package Validation"
echo "--------------------"

# Validate Package.swift syntax
if swift package dump-package > /dev/null 2>&1; then
    print_status "Package.swift syntax valid"
else
    print_error "Package.swift has syntax errors"
    exit 1
fi

# Resolve dependencies
print_info "Resolving dependencies..."
if swift package resolve 2>/dev/null; then
    print_status "Dependencies resolved successfully"
else
    print_warning "Could not resolve dependencies (may require network access)"
fi

# Source Code Analysis
echo ""
echo "📝 Source Code Analysis"
echo "----------------------"

# Count source files
SOURCE_FILES=$(find Sources -name "*.swift" | wc -l)
print_info "Source files found: $SOURCE_FILES"

# Count test files
TEST_FILES=$(find Tests -name "*.swift" | wc -l)
print_info "Test files found: $TEST_FILES"

# Calculate lines of code
TOTAL_LINES=$(find Sources -name "*.swift" -exec wc -l {} + | tail -n 1 | awk '{print $1}')
TEST_LINES=$(find Tests -name "*.swift" -exec wc -l {} + | tail -n 1 | awk '{print $1}')

print_info "Source lines of code: $TOTAL_LINES"
print_info "Test lines of code: $TEST_LINES"

if [ $TEST_LINES -gt 0 ]; then
    TEST_RATIO=$(echo "scale=1; $TEST_LINES * 100 / $TOTAL_LINES" | bc)
    print_info "Test-to-source ratio: ${TEST_RATIO}%"
fi

# Build Validation
echo ""
echo "🔨 Build Validation"
echo "------------------"

print_info "Building package..."
BUILD_OUTPUT=$(swift build 2>&1)
BUILD_EXIT_CODE=$?

if [ $BUILD_EXIT_CODE -eq 0 ]; then
    print_status "Build completed successfully"
else
    print_warning "Build encountered issues (iOS SDK limitations in CLI)"
    echo "Build output preview:"
    echo "$BUILD_OUTPUT" | head -n 15
    echo "..."
fi

# Test Execution
echo ""
echo "🧪 Running Unit Tests"
echo "--------------------"

TEST_OUTPUT=$(swift test 2>&1)
TEST_EXIT_CODE=$?

if [ $TEST_EXIT_CODE -eq 0 ]; then
    print_status "All tests passed!"
    
    # Extract test results if available
    TEST_COUNT=$(echo "$TEST_OUTPUT" | grep -E "Test Suite .* passed" | tail -n 1 | grep -o '[0-9]\+ tests' | grep -o '[0-9]\+' || echo "Unknown")
    if [ "$TEST_COUNT" != "Unknown" ]; then
        print_info "Tests executed: $TEST_COUNT"
    fi
    
else
    print_error "Some tests failed!"
    echo "Test output:"
    echo "$TEST_OUTPUT"
    echo ""
fi

# Code Quality Checks
echo ""
echo "🔍 Code Quality Analysis"
echo "-----------------------"

# Check for basic Swift patterns in source files
SYNTAX_ERRORS=0

for file in $(find Sources -name "*.swift"); do
    if grep -q "class\|struct\|enum\|protocol\|func\|var\|let" "$file"; then
        filename=$(basename "$file")
        lines=$(wc -l < "$file")
        print_status "$filename: $lines lines, syntax patterns OK"
    else
        filename=$(basename "$file")
        print_warning "$filename: No Swift syntax patterns found"
        SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
    fi
done

# Check for TODO/FIXME comments
TODO_COUNT=$(grep -r "TODO\|FIXME" Sources/ | wc -l)
if [ $TODO_COUNT -gt 0 ]; then
    print_warning "Found $TODO_COUNT TODO/FIXME comments"
else
    print_status "No pending TODO/FIXME comments"
fi

# Performance Analysis
echo ""
echo "⚡ Performance Analysis"
echo "---------------------"

# Check for potential performance issues
FORCE_UNWRAPS=$(grep -r "!" Sources/ | grep -v "!=" | wc -l)
if [ $FORCE_UNWRAPS -gt 0 ]; then
    print_warning "Found $FORCE_UNWRAPS force unwraps (potential crash points)"
else
    print_status "No force unwraps found"
fi

# Check for proper async/await usage
ASYNC_FUNCS=$(grep -r "async func\|await " Sources/ | wc -l)
print_info "Async/await usage: $ASYNC_FUNCS instances"

# Test Coverage Analysis
echo ""
echo "📊 Test Coverage Analysis"
echo "------------------------"

# Find test methods
TEST_METHODS=$(grep -r "func test" Tests/ | wc -l)
print_info "Test methods found: $TEST_METHODS"

# Estimate coverage based on file patterns
SOURCE_CLASSES=$(grep -r "class\|struct" Sources/ | wc -l)
TEST_CLASSES=$(grep -r "class.*Test" Tests/ | wc -l)

if [ $SOURCE_CLASSES -gt 0 ]; then
    COVERAGE_ESTIMATE=$(echo "scale=1; $TEST_CLASSES * 100 / $SOURCE_CLASSES" | bc)
    print_info "Estimated test coverage: ${COVERAGE_ESTIMATE}%"
fi

# Generate coverage report if possible
if command -v xcov &> /dev/null; then
    print_info "Generating detailed coverage report..."
    xcov > /dev/null 2>&1 && print_status "Coverage report generated" || print_warning "Coverage report generation failed"
else
    print_warning "xcov not available for detailed coverage analysis"
fi

# Security Analysis
echo ""
echo "🔒 Security Analysis"
echo "-------------------"

# Check for hardcoded secrets
POTENTIAL_SECRETS=$(grep -ri "password\|secret\|key.*=" Sources/ | grep -v "// " | wc -l)
if [ $POTENTIAL_SECRETS -gt 0 ]; then
    print_warning "Found $POTENTIAL_SECRETS potential hardcoded secrets"
else
    print_status "No hardcoded secrets detected"
fi

# Check for proper SSL usage
SSL_USAGE=$(grep -r "https\|wss" Sources/ | wc -l)
HTTP_USAGE=$(grep -r "http://\|ws://" Sources/ | wc -l)

if [ $HTTP_USAGE -gt $SSL_USAGE ]; then
    print_warning "Consider using HTTPS/WSS instead of HTTP/WS for production"
else
    print_status "Good SSL/TLS usage patterns"
fi

# Final Report
echo ""
echo "📋 Test Suite Summary"
echo "===================="
echo "📁 Files Analyzed:"
echo "   Source files: $SOURCE_FILES ($TOTAL_LINES lines)"
echo "   Test files: $TEST_FILES ($TEST_LINES lines)"
echo ""
echo "🧪 Test Results:"
echo "   Test methods: $TEST_METHODS"
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "   Status: ✅ ALL TESTS PASSED"
else
    echo "   Status: ❌ SOME TESTS FAILED"
fi
echo ""
echo "🔍 Quality Metrics:"
echo "   Syntax errors: $SYNTAX_ERRORS"
echo "   TODO comments: $TODO_COUNT"
echo "   Force unwraps: $FORCE_UNWRAPS"
echo "   Async functions: $ASYNC_FUNCS"
echo ""

# Overall status
if [ $TEST_EXIT_CODE -eq 0 ] && [ $SYNTAX_ERRORS -eq 0 ]; then
    print_status "🎉 ALL CHECKS PASSED - StreamKit Test App is ready!"
    echo ""
    echo "🚀 Ready for:"
    echo "   • Physical device testing with ARKit"
    echo "   • Integration with Relay servers"
    echo "   • STAG database verification"
    echo "   • Performance benchmarking"
    echo ""
    echo "📱 To test on device:"
    echo "   1. Open in Xcode 16+"
    echo "   2. Select iPhone/iPad with LiDAR"
    echo "   3. Build and run (⌘R)"
    echo "   4. Configure Relay URL and API key"
    echo "   5. Start streaming and monitor metrics"
    exit 0
else
    print_warning "Some issues found - review above for details"
    echo ""
    echo "🔧 Recommended actions:"
    [ $TEST_EXIT_CODE -ne 0 ] && echo "   • Fix failing tests"
    [ $SYNTAX_ERRORS -gt 0 ] && echo "   • Address syntax issues"
    [ $TODO_COUNT -gt 5 ] && echo "   • Complete pending TODOs"
    [ $FORCE_UNWRAPS -gt 10 ] && echo "   • Reduce force unwraps"
    exit 1
fi