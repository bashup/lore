## Integration Tests

While our unit tests verify that `lore` will invoke the correct bash commands (according to the spec), these tests are a sanity check that `lore`'s behavior-as-specified is correct according to what *bash* will actually do in "real life".  That is, will it read from and write to the correct files with the correct commands...  or do something weird and inexplicable that you have to squint sideways at the bash manual for an hour or two to tell if it's a bash bug or not.

### Setup and Fixtures

~~~sh
# Use a salted lorefile name to prevent false positive matches with local lorefiles
    $ export LORE_FILE=".lore-test-${CRAMTMP##*-}"

# Generate the output files from the "Text Fixtures" section below
    $ mdsh "$TESTDIR/$TESTFILE"
~~~

#### Configure History and Lore

We configure bash history to ignore cram's separator lines ( `echo salt lineno $?`), `history` commands,  `lore prompt`, and lines ending in ` #nohist`.  Then we enable lore and history.

~~~sh
# Ignore 
    $ HISTIGNORE='&:echo * * $[?]:history:history *:lore prompt:* #nohist'

# activate lore
    $ source lore on

# Enable history and run the first prompt
    $ HISTFILE=$HOME/.bash_history
    $ set -o history
    $ lore prompt

# History is what we got from .bash_history
    $ history
        1  ls
        2  pwd
        3  cd projects/php
~~~

### Basic project entry/departure

~~~sh
    $ cd projects/node
    $ lore prompt
    lore: loading history from .lore-test-* (glob)

    $ ls
    $ lore prompt

    $ history
        1  yarn set version berry
        2  yarn add typescript --dev
        3  yarn dev
        4  ls

    $ cd ..
    $ lore prompt
    lore: loading history from ~/.bash_history

    $ history
        1  ls
        2  pwd
        3  cd projects/php
        4  cd projects/node

    $ cd node
    $ lore prompt
    lore: loading history from .lore-test-* (glob)

    $ history
        1  yarn set version berry
        2  yarn add typescript --dev
        3  yarn dev
        4  ls
~~~

### Save history to a new project

~~~sh
    $ mkdir ../new-node
    $ lore prompt
    $ lore save ../new-node

    $ cd ../new-node
    $ lore prompt
    lore: loading history from .lore-test-* (glob)
    $ history
        1  yarn set version berry
        2  yarn add typescript --dev
        3  yarn dev
        4  ls
        5  mkdir ../new-node
        6  lore save ../new-node

~~~

## Test Fixtures

The remainder of this file is an mdsh script to generate sample files and directories to be used in the tests above.

### Directories

```shell
mkdir -p projects/{php,node,shell}
```

### .bash_history

```sh |cat >.bash_history
ls
pwd
cd projects/php
```

### projects/php

```sh |cat >projects/php/"$LORE_FILE"
composer install
composer test
```

### projects/node

```sh |cat >projects/node/"$LORE_FILE"
yarn set version berry
yarn add typescript --dev
yarn dev
```

### projects/shell

```sh |cat >projects/shell/"$LORE_FILE"
.devkit/setup
nano .dkrc
nano package.sh
dk watch
```

