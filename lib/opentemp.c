/*
 * Copyright (c) 2018 Stefan Sperling <stsp@openbsd.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#include <fcntl.h>
#include <limits.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>

#include "openbsd-compat.h"

#include "got_opentemp.h"
#include "got_error.h"

int
got_opentempfd(void)
{
	char name[PATH_MAX];
	int fd;

	if (strlcpy(name, GOT_TMPDIR_STR "/got.XXXXXXXX", sizeof(name))
	    >= sizeof(name))
		return -1;

	fd = mkstemp(name);
	if (fd != -1)
		unlink(name);
	return fd;
}

FILE *
got_opentemp(void)
{
	int fd;
	FILE *f;

	fd = got_opentempfd();
	if (fd < 0)
		return NULL;

	f = fdopen(fd, "w+");
	if (f == NULL) {
		close(fd);
		return NULL;
	}

	return f;
}

const struct got_error *
got_opentemp_named(char **path, FILE **outfile, const char *basepath)
{
	return got_opentemp_namedat(AT_FDCWD, path, outfile, basepath);
}

const struct got_error *
got_opentemp_namedat(int dir_fd, char **path, FILE **outfile, const char *basepath)
{
	const struct got_error *err = NULL;
	char *old_cwd = NULL;
	int fd, chdir_err;

	*outfile = NULL;

	if (asprintf(path, "%s-XXXXXX", basepath) == -1) {
		*path = NULL;
		return got_error_from_errno("asprintf");
	}

	if (dir_fd != AT_FDCWD) {
		old_cwd = getcwd(NULL, 0);
		if (old_cwd == NULL)
			return got_error_from_errno("getcwd");
		chdir_err = fchdir(dir_fd);
		if (chdir_err == -1) {
			free(old_cwd);
			return got_error_from_errno("fchdir");
		}
	}

	fd = mkstemp(*path);

	if (dir_fd != AT_FDCWD) {
		chdir_err = chdir(old_cwd);
		if (chdir_err == -1) {
			free(old_cwd);
			return got_error_from_errno("fchdir");
		}
		free(old_cwd);
	}

	if (fd == -1) {
		err = got_error_from_errno2("mkstemp", *path);
		free(*path);
		*path = NULL;
		return err;
	}

	*outfile = fdopen(fd, "w+");
	if (*outfile == NULL) {
		err = got_error_from_errno2("fdopen", *path);
		free(*path);
		*path = NULL;
	}

	return err;
}

const struct got_error *
got_opentemp_named_fd(char **path, int *outfd, const char *basepath)
{
	return got_opentemp_named_fdat(AT_FDCWD, path, outfd, basepath);
}
const struct got_error *
got_opentemp_named_fdat(int dir_fd, char **path, int *outfd, const char *basepath)
{
	const struct got_error *err = NULL;
	char *old_cwd;
	int fd, chdir_err;

	*outfd = -1;

	if (asprintf(path, "%s-XXXXXX", basepath) == -1) {
		*path = NULL;
		return got_error_from_errno("asprintf");
	}

	if (dir_fd != AT_FDCWD) {
		old_cwd = getcwd(NULL, 0);
		if (old_cwd == NULL)
			return got_error_from_errno("getcwd");
		chdir_err = fchdir(dir_fd);
		if (chdir_err == -1) {
			free(old_cwd);
			return got_error_from_errno("fchdir");
		}
	}

	fd = mkstemp(*path);

	if (fd == -1) {
		err = got_error_from_errno2("mkstemp", *path);
		free(*path);
		*path = NULL;
		if (old_cwd)
			free(old_cwd);
		return err;
	}

	if (dir_fd != AT_FDCWD) {
		chdir_err = chdir(old_cwd);
		if (chdir_err == -1) {
			free(old_cwd);
			return got_error_from_errno("fchdir");
		}
		free(old_cwd);
	}

	*outfd = fd;
	return err;
}
