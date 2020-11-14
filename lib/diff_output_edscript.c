/* Produce ed(1) script output from a diff_result. */
/*
 * Copyright (c) 2020 Neels Hofmeyr <neels@hofmeyr.de>
 * Copyright (c) 2020 Stefan Sperling <stsp@openbsd.org>
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

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#include <arraylist.h>
#include <diff_main.h>
#include <diff_output.h>

#include "diff_internal.h"

static int
output_edscript_chunk(struct diff_output_info *outinfo,
    FILE *dest, const struct diff_input_info *info,
    const struct diff_result *result,
    struct diff_chunk_context *cc)
{
	off_t outoff = 0, *offp;
	int left_start, left_len, right_start, right_len;
	int rc;

	left_len = cc->left.end - cc->left.start;
	if (left_len < 0)
		return EINVAL;
	else if (result->left->atoms.len == 0)
		left_start = 0;
	else if (left_len == 0 && cc->left.start > 0)
		left_start = cc->left.start;
	else
		left_start = cc->left.start + 1;

	right_len = cc->right.end - cc->right.start;
	if (right_len < 0)
		return EINVAL;
	else if (result->right->atoms.len == 0)
		right_start = 0;
	else if (right_len == 0 && cc->right.start > 0)
		right_start = cc->right.start;
	else
		right_start = cc->right.start + 1;

	if (left_len == 0) {
		/* addition */
		if (right_len == 1) {
			rc = fprintf(dest, "%da%d\n", left_start, right_start);
		} else {
			rc = fprintf(dest, "%da%d,%d\n", left_start,
			    right_start, cc->right.end);
		}
	} else if (right_len == 0) {
		/* deletion */
		if (left_len == 1) {
			rc = fprintf(dest, "%dd%d\n", left_start,
			    right_start);
		} else {
			rc = fprintf(dest, "%d,%dd%d\n", left_start,
			    cc->left.end, right_start);
		}
	} else {
		/* change */
		if (left_len == 1 && right_len == 1) {
			rc = fprintf(dest, "%dc%d\n", left_start, right_start);
		} else if (left_len == 1) {
			rc = fprintf(dest, "%dc%d,%d\n", left_start,
			    right_start, cc->right.end);
		} else if (right_len == 1) {
			rc = fprintf(dest, "%d,%dc%d\n", left_start,
			    cc->left.end, right_start);
		} else {
			rc = fprintf(dest, "%d,%dc%d,%d\n", left_start,
			    cc->left.end, right_start, cc->right.end);
		}
	}
	if (rc < 0)
		return errno;
	if (outinfo) {
		ARRAYLIST_ADD(offp, outinfo->line_offsets);
		if (offp == NULL)
			return ENOMEM;
		outoff += rc;
		*offp = outoff;
	}

	return DIFF_RC_OK;
}

int
diff_output_edscript(struct diff_output_info **output_info,
    FILE *dest, const struct diff_input_info *info,
    const struct diff_result *result)
{
	struct diff_output_info *outinfo = NULL;
	struct diff_chunk_context cc = {};
	int i, rc;

	if (!result)
		return EINVAL;
	if (result->rc != DIFF_RC_OK)
		return result->rc;

	if (output_info) {
		*output_info = diff_output_info_alloc();
		if (*output_info == NULL)
			return ENOMEM;
		outinfo = *output_info;
	}

	for (i = 0; i < result->chunks.len; i++) {
		struct diff_chunk *chunk = &result->chunks.head[i];
		enum diff_chunk_type t = diff_chunk_type(chunk);
		struct diff_chunk_context next;

		if (t != CHUNK_MINUS && t != CHUNK_PLUS)
			continue;

		if (diff_chunk_context_empty(&cc)) {
			/* Note down the start point, any number of subsequent
			 * chunks may be joined up to this chunk by being
			 * directly adjacent. */
			diff_chunk_context_get(&cc, result, i, 0);
			continue;
		}

		/* There already is a previous chunk noted down for being
		 * printed. Does it join up with this one? */
		diff_chunk_context_get(&next, result, i, 0);

		if (diff_chunk_contexts_touch(&cc, &next)) {
			/* This next context touches or overlaps the previous
			 * one, join. */
			diff_chunk_contexts_merge(&cc, &next);
			continue;
		}

		rc = output_edscript_chunk(outinfo, dest, info, result, &cc);
		if (rc != DIFF_RC_OK)
			return rc;
		cc = next;
	}

	if (!diff_chunk_context_empty(&cc))
		return output_edscript_chunk(outinfo, dest, info, result, &cc);
	return DIFF_RC_OK;
}
