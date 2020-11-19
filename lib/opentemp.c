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

#include <limits.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>

#include "openbsd-compat.h"

#include "got_opentemp.h"
#include "got_error.h"

#include <fcntl.h>
#include <sys/capsicum.h>
#include <capsicum_helpers.h>

static int tempdir_fd;

const struct got_error *
got_opentemp_opendir(void)
{
	cap_rights_t rights;

	tempdir_fd = open(GOT_TMPDIR_STR, O_DIRECTORY);
	if (tempdir_fd == -1)
		return got_error_from_errno("open");
	cap_rights_init(&rights, CAP_READ, CAP_WRITE, CAP_LOOKUP, CAP_CREATE,
	    CAP_FCNTL, CAP_UNLINKAT, CAP_FSTAT, CAP_SEEK);
	if (caph_rights_limit(tempdir_fd, &rights) < 0)
		return got_error_from_errno("caph_rights_limit");
	return NULL;
}

int
got_opentempfd(void)
{
	char name[PATH_MAX];
	int fd;

	if (strlcpy(name, "got.XXXXXXXX", sizeof(name))
	    >= sizeof(name))
		return -1;

	fd = mkostempsat(tempdir_fd, name, 0, 0);
	if (fd != -1)
		unlinkat(tempdir_fd, name, 0);
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
got_opentemp_named(int dir_fd, char **path, FILE **outfile, const char *basepath)
{
	const struct got_error *err = NULL;
	int fd;

	*outfile = NULL;

	if (asprintf(path, "%s-XXXXXX", basepath) == -1) {
		*path = NULL;
		return got_error_from_errno("asprintf");
	}

	fd = mkostempsat(dir_fd, *path, 0, 0);
	if (fd == -1) {
		err = got_error_from_errno2("mkostempsat", *path);
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
	const struct got_error *err = NULL;
	int fd;

	*outfd = -1;

	if (asprintf(path, "%s-XXXXXX", basepath) == -1) {
		*path = NULL;
		return got_error_from_errno("asprintf");
	}

	fd = mkstemp(*path);
	if (fd == -1) {
		err = got_error_from_errno("mkstemp");
		free(*path);
		*path = NULL;
		return err;
	}

	*outfd = fd;
	return err;
}
