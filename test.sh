# run_tests.sh
#!/bin/bash

echo "JRuby Unix Socket Tests"
echo "======================="
echo ""

# Check versions
echo "Environment:"
java -version 2>&1 | head -n 1
jruby --version
echo ""

# Clean up
rm -f /tmp/test_*.sock

# Run tests
echo "Running tests..."
jruby test_sockets.rb

echo ""
echo "Done."
