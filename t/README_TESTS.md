# A Note on Tests

All tests require PLERD_HOME to be set.  Running tests with the .runtests.pl script will set this correctly:

    t/.runtests.pl t/000-compile.t

The top-level Makefile runs all *.t files in this directory:

    make && echo OK

As a personal preference, I like to see make print OK if everything went well.  You need not invoke it this way.

The naming scheme for the test files roughly follows the pattern of:

    000 - 019 essential classes needed for other classes
    020 - 099 models
    100+      integration tests
