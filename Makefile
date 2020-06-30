TEST_FILES = t/*.t

test : $(TEST_FILES)
	perl t/.runtests.pl $(TEST_FILES)


    