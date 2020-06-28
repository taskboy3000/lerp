# A Note on Tests

All tests require PLERD_HOME to be set.  Running tests with the .runtests.pl script will set this correctly:

```
    t/.runtests.pl t/000-compile.t
```

The top-level Makefile runs all *.t files in this directory:

```
    make && echo OK
```

As a personal preference, I like to see make print OK if everything went well.  You need not invoke it this way.

The naming scheme for the test files roughly follows the pattern of:

```
    000 - 019 essential classes needed for other classes
    020 - 099 models
    100+      integration tests
```

When I have to debug individual tests in the debugger, I change to the t directory and type:

```
    $ PLERD_HOME=.. perl -d 000-compile.t
```

Replace 000-compile.t with the test you wish to debug. 

## Creating new tests

In the t directory, there is a file called .make_test.pl which is invoked with a test name:

```
    $ ./.make_test.pl 060-conv.t
```

This would make a new test called '060-conv.t' which is runnable, but fatuous.  Create new subroutines that start with the name Test, like:

```
    sub TestIntConversion {
        ok("2" == 2, 'Testing string to integer conversion');
    }
```

Of course, new tests will ideally be testing code with this project rather than core Perl.

Invoke this test from the provided Main function, like the following code demonstrates.

```
    sub Main {
        setup();

        # Invoke tests here
        TestIntConversion();

        teardown();
        done_testing();
    }
```

## Baselines

Creating baselines for a blogging system is a little tricky, since some much of the content contains dates and other non-generic data.  Using the source models in the t directoy, a default site can be generated.  The docroot of that site has been checked in to git.  When 100-plerd.t runs, baselines are found by stripping off pub dates from filenames.  The size of content is then compared.  Again, there may be some dates that change within the content, so the different between the size of the two contents is compared.  If the difference is more that 10 characters, there may be a problem.  That fudge factor of 10 bytes is completely arbitrary and may need to be reconsidered in the future. 