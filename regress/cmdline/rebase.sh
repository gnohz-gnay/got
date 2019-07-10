#!/bin/sh
#
# Copyright (c) 2019 Stefan Sperling <stsp@openbsd.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

. ./common.sh

function test_rebase_basic {
	local testroot=`test_init rebase_basic`

	(cd $testroot/repo && git checkout -q -b newbranch)
	echo "modified delta on branch" > $testroot/repo/gamma/delta
	git_commit $testroot/repo -m "committing to delta on newbranch"

	echo "modified alpha on branch" > $testroot/repo/alpha
	(cd $testroot/repo && git rm -q beta)
	echo "new file on branch" > $testroot/repo/epsilon/new
	(cd $testroot/repo && git add epsilon/new)
	git_commit $testroot/repo -m "committing more changes on newbranch"

	local orig_commit1=`git_show_parent_commit $testroot/repo`
	local orig_commit2=`git_show_head $testroot/repo`

	(cd $testroot/repo && git checkout -q master)
	echo "modified zeta on master" > $testroot/repo/epsilon/zeta
	git_commit $testroot/repo -m "committing to zeta on master"
	local master_commit=`git_show_head $testroot/repo`

	got checkout $testroot/repo $testroot/wt > /dev/null
	ret="$?"
	if [ "$ret" != "0" ]; then
		test_done "$testroot" "$ret"
		return 1
	fi

	(cd $testroot/wt && got rebase newbranch > $testroot/stdout)

	(cd $testroot/repo && git checkout -q newbranch)
	local new_commit1=`git_show_parent_commit $testroot/repo`
	local new_commit2=`git_show_head $testroot/repo`

	local short_orig_commit1=`trim_obj_id 28 $orig_commit1`
	local short_orig_commit2=`trim_obj_id 28 $orig_commit2`
	local short_new_commit1=`trim_obj_id 28 $new_commit1`
	local short_new_commit2=`trim_obj_id 28 $new_commit2`

	echo "G  gamma/delta" >> $testroot/stdout.expected
	echo -n "$short_orig_commit1 -> $short_new_commit1" \
		>> $testroot/stdout.expected
	echo ": committing to delta on newbranch" >> $testroot/stdout.expected
	echo "G  alpha" >> $testroot/stdout.expected
	echo "D  beta" >> $testroot/stdout.expected
	echo "A  epsilon/new" >> $testroot/stdout.expected
	echo -n "$short_orig_commit2 -> $short_new_commit2" \
		>> $testroot/stdout.expected
	echo ": committing more changes on newbranch" \
		>> $testroot/stdout.expected
	echo "Switching work tree to refs/heads/newbranch" \
		>> $testroot/stdout.expected

	cmp -s $testroot/stdout.expected $testroot/stdout
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/stdout.expected $testroot/stdout
		test_done "$testroot" "$ret"
		return 1
	fi

	echo "modified delta on branch" > $testroot/content.expected
	cat $testroot/wt/gamma/delta > $testroot/content
	cmp -s $testroot/content.expected $testroot/content
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/content.expected $testroot/content
		test_done "$testroot" "$ret"
		return 1
	fi

	echo "modified alpha on branch" > $testroot/content.expected
	cat $testroot/wt/alpha > $testroot/content
	cmp -s $testroot/content.expected $testroot/content
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/content.expected $testroot/content
		test_done "$testroot" "$ret"
		return 1
	fi

	if [ -e $testroot/wt/beta ]; then
		echo "removed file beta still exists on disk" >&2
		test_done "$testroot" "1"
		return 1
	fi

	echo "new file on branch" > $testroot/content.expected
	cat $testroot/wt/epsilon/new > $testroot/content
	cmp -s $testroot/content.expected $testroot/content
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/content.expected $testroot/content
		test_done "$testroot" "$ret"
		return 1
	fi

	(cd $testroot/wt && got status > $testroot/stdout)

	echo -n > $testroot/stdout.expected
	cmp -s $testroot/stdout.expected $testroot/stdout
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/stdout.expected $testroot/stdout
		test_done "$testroot" "$ret"
		return 1
	fi

	(cd $testroot/wt && got log -l3 | grep ^commit > $testroot/stdout)
	echo "commit $new_commit2 (newbranch)" > $testroot/stdout.expected
	echo "commit $new_commit1" >> $testroot/stdout.expected
	echo "commit $master_commit (master)" >> $testroot/stdout.expected
	cmp -s $testroot/stdout.expected $testroot/stdout
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/stdout.expected $testroot/stdout
	fi
	test_done "$testroot" "$ret"
}

function test_rebase_ancestry_check {
	local testroot=`test_init rebase_ancestry_check`

	got checkout $testroot/repo $testroot/wt > /dev/null
	ret="$?"
	if [ "$ret" != "0" ]; then
		test_done "$testroot" "$ret"
		return 1
	fi

	(cd $testroot/repo && git checkout -q -b newbranch)
	echo "modified delta on branch" > $testroot/repo/gamma/delta
	git_commit $testroot/repo -m "committing to delta on newbranch"

	(cd $testroot/wt && got rebase newbranch > $testroot/stdout \
		2> $testroot/stderr)

	echo -n > $testroot/stdout.expected
	cmp -s $testroot/stdout.expected $testroot/stdout
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/stdout.expected $testroot/stdout
		test_done "$testroot" "$ret"
		return 1
	fi

	echo -n "got: specified branch resolves to a commit " \
		> $testroot/stderr.expected
	echo "which is already contained in work tree's branch" \
		>> $testroot/stderr.expected
	cmp -s $testroot/stderr.expected $testroot/stderr
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/stderr.expected $testroot/stderr
	fi
	test_done "$testroot" "$ret"
}

function test_rebase_continue {
	local testroot=`test_init rebase_continue`

	(cd $testroot/repo && git checkout -q -b newbranch)
	echo "modified alpha on branch" > $testroot/repo/alpha
	git_commit $testroot/repo -m "committing to alpha on newbranch"
	local orig_commit1=`git_show_head $testroot/repo`

	(cd $testroot/repo && git checkout -q master)
	echo "modified alpha on master" > $testroot/repo/alpha
	git_commit $testroot/repo -m "committing to alpha on master"
	local master_commit=`git_show_head $testroot/repo`

	got checkout $testroot/repo $testroot/wt > /dev/null
	ret="$?"
	if [ "$ret" != "0" ]; then
		test_done "$testroot" "$ret"
		return 1
	fi

	(cd $testroot/wt && got rebase newbranch > $testroot/stdout \
		2> $testroot/stderr)

	echo "C  alpha" > $testroot/stdout.expected
	cmp -s $testroot/stdout.expected $testroot/stdout
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/stdout.expected $testroot/stdout
		test_done "$testroot" "$ret"
		return 1
	fi

	echo "got: conflicts must be resolved before rebase can be resumed" \
		> $testroot/stderr.expected
	cmp -s $testroot/stderr.expected $testroot/stderr
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/stderr.expected $testroot/stderr
		test_done "$testroot" "$ret"
		return 1
	fi

	echo "<<<<<<< commit $orig_commit1" > $testroot/content.expected
	echo "modified alpha on branch" >> $testroot/content.expected
	echo "=======" >> $testroot/content.expected
	echo "modified alpha on master" >> $testroot/content.expected
	echo '>>>>>>> alpha' >> $testroot/content.expected
	cat $testroot/wt/alpha > $testroot/content
	cmp -s $testroot/content.expected $testroot/content
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/content.expected $testroot/content
		test_done "$testroot" "$ret"
		return 1
	fi

	(cd $testroot/wt && got status > $testroot/stdout)

	echo "C  alpha" > $testroot/stdout.expected
	cmp -s $testroot/stdout.expected $testroot/stdout
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/stdout.expected $testroot/stdout
		test_done "$testroot" "$ret"
		return 1
	fi

	# resolve the conflict
	echo "modified alpha on branch and master" > $testroot/wt/alpha

	(cd $testroot/wt && got rebase -c > $testroot/stdout)

	(cd $testroot/repo && git checkout -q newbranch)
	local new_commit1=`git_show_head $testroot/repo`

	local short_orig_commit1=`trim_obj_id 28 $orig_commit1`
	local short_new_commit1=`trim_obj_id 28 $new_commit1`

	echo -n "$short_orig_commit1 -> $short_new_commit1" \
		> $testroot/stdout.expected
	echo ": committing to alpha on newbranch" >> $testroot/stdout.expected
	echo "Switching work tree to refs/heads/newbranch" \
		>> $testroot/stdout.expected

	cmp -s $testroot/stdout.expected $testroot/stdout
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/stdout.expected $testroot/stdout
		test_done "$testroot" "$ret"
		return 1
	fi


	(cd $testroot/wt && got log -l2 | grep ^commit > $testroot/stdout)
	echo "commit $new_commit1 (newbranch)" > $testroot/stdout.expected
	echo "commit $master_commit (master)" >> $testroot/stdout.expected
	cmp -s $testroot/stdout.expected $testroot/stdout
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/stdout.expected $testroot/stdout
	fi
	test_done "$testroot" "$ret"
}

function test_rebase_abort {
	local testroot=`test_init rebase_abort`

	local init_commit=`git_show_head $testroot/repo`

	(cd $testroot/repo && git checkout -q -b newbranch)
	echo "modified alpha on branch" > $testroot/repo/alpha
	git_commit $testroot/repo -m "committing to alpha on newbranch"
	local orig_commit1=`git_show_head $testroot/repo`

	(cd $testroot/repo && git checkout -q master)
	echo "modified alpha on master" > $testroot/repo/alpha
	git_commit $testroot/repo -m "committing to alpha on master"
	local master_commit=`git_show_head $testroot/repo`

	got checkout $testroot/repo $testroot/wt > /dev/null
	ret="$?"
	if [ "$ret" != "0" ]; then
		test_done "$testroot" "$ret"
		return 1
	fi

	(cd $testroot/wt && got rebase newbranch > $testroot/stdout \
		2> $testroot/stderr)

	echo "C  alpha" > $testroot/stdout.expected
	cmp -s $testroot/stdout.expected $testroot/stdout
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/stdout.expected $testroot/stdout
		test_done "$testroot" "$ret"
		return 1
	fi

	echo "got: conflicts must be resolved before rebase can be resumed" \
		> $testroot/stderr.expected
	cmp -s $testroot/stderr.expected $testroot/stderr
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/stderr.expected $testroot/stderr
		test_done "$testroot" "$ret"
		return 1
	fi

	echo "<<<<<<< commit $orig_commit1" > $testroot/content.expected
	echo "modified alpha on branch" >> $testroot/content.expected
	echo "=======" >> $testroot/content.expected
	echo "modified alpha on master" >> $testroot/content.expected
	echo '>>>>>>> alpha' >> $testroot/content.expected
	cat $testroot/wt/alpha > $testroot/content
	cmp -s $testroot/content.expected $testroot/content
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/content.expected $testroot/content
		test_done "$testroot" "$ret"
		return 1
	fi

	(cd $testroot/wt && got status > $testroot/stdout)

	echo "C  alpha" > $testroot/stdout.expected
	cmp -s $testroot/stdout.expected $testroot/stdout
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/stdout.expected $testroot/stdout
		test_done "$testroot" "$ret"
		return 1
	fi

	(cd $testroot/wt && got rebase -a > $testroot/stdout)

	(cd $testroot/repo && git checkout -q newbranch)

	echo "Switching work tree to refs/heads/master" \
		> $testroot/stdout.expected
	echo 'R  alpha' >> $testroot/stdout.expected
	echo "Rebase of refs/heads/newbranch aborted" \
		>> $testroot/stdout.expected

	cmp -s $testroot/stdout.expected $testroot/stdout
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/stdout.expected $testroot/stdout
		test_done "$testroot" "$ret"
		return 1
	fi

	echo "modified alpha on master" > $testroot/content.expected
	cat $testroot/wt/alpha > $testroot/content
	cmp -s $testroot/content.expected $testroot/content
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/content.expected $testroot/content
		test_done "$testroot" "$ret"
		return 1
	fi

	(cd $testroot/wt && got log -l3 -c newbranch \
		| grep ^commit > $testroot/stdout)
	echo "commit $orig_commit1 (newbranch)" > $testroot/stdout.expected
	echo "commit $init_commit" >> $testroot/stdout.expected
	cmp -s $testroot/stdout.expected $testroot/stdout
	ret="$?"
	if [ "$ret" != "0" ]; then
		diff -u $testroot/stdout.expected $testroot/stdout
	fi
	test_done "$testroot" "$ret"
}

run_test test_rebase_basic
run_test test_rebase_ancestry_check
run_test test_rebase_continue
run_test test_rebase_abort
