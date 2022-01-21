export testfile="testfile.txt"
echo "testfile=${testfile}" >> $GITHUB_ENV
echo "my test artifact " > $testfile