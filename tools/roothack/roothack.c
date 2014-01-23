/*-
 * Copyright (c) 2010-2012 Ed Schouten <ed@FreeBSD.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <sys/param.h>
#include <sys/linker.h>
#include <sys/module.h>
#include <sys/mount.h>
#include <sys/uio.h>

#include <archive.h>
#include <archive_entry.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void
die(const char *msg)
{
	int fd, serrno;

	serrno = errno;
	fd = open("/dev/console", O_RDWR);
	if (fd != -1 && fd != STDERR_FILENO)
		dup2(fd, STDERR_FILENO);
	errno = serrno;
	perror(msg);
	sleep(10);
	exit(1);
}

static void
domount(const char * const list[], unsigned int elems)
{
	struct iovec iov[elems];
	unsigned int i;

	for (i = 0; i < elems; i++) {
		iov[i].iov_base = __DECONST(char *, list[i]);
		iov[i].iov_len = strlen(list[i]) + 1;
	}

	if (nmount(iov, elems, 0) != 0)
		die(list[1]);
}

static int
copy_data(struct archive *ar, struct archive *aw)
{
	int r;
	const void *buff;
	size_t size;
	off_t offset;

	for (;;) {
		r = archive_read_data_block(ar, &buff, &size, &offset);
		if (r == ARCHIVE_EOF)
			return (ARCHIVE_OK);
		if (r != ARCHIVE_OK)
			return (r);
		r = archive_write_data_block(aw, buff, size, offset);
		if (r != ARCHIVE_OK) {
			die(archive_error_string(aw));
			return (r);
		}
	}
}

static void
extract(const char *filename)
{
	struct archive *a;
	struct archive *ext;
	struct archive_entry *entry;
	int flags;
	int r;

	flags = ARCHIVE_EXTRACT_OWNER | ARCHIVE_EXTRACT_PERM;

	a = archive_read_new();
	archive_read_support_format_all(a);
#if ARCHIVE_VERSION_NUMBER < 3000000
	archive_read_support_compression_all(a);
#else
	archive_read_support_filter_all(a);
#endif
	ext = archive_write_disk_new();
	archive_write_disk_set_options(ext, flags);
	archive_write_disk_set_standard_lookup(ext);
#if ARCHIVE_VERSION_NUMBER < 3000000
	if ((r = archive_read_open_file(a, filename, 10240)))
		die("archive_read_open_file");
#else
	if ((r = archive_read_open_filename(a, filename, 10240)))
		die("archive_read_open_filename");
#endif
	for (;;) {
		r = archive_read_next_header(a, &entry);
		if (r == ARCHIVE_EOF)
			break;
		if (r < ARCHIVE_WARN)
			die(archive_error_string(a));
		r = archive_write_header(ext, entry);
		if (r == ARCHIVE_OK && archive_entry_size(entry) > 0) {
			r = copy_data(a, ext);
			if (r < ARCHIVE_WARN)
				die(archive_error_string(a));
		}
		r = archive_write_finish_entry(ext);
		if (r < ARCHIVE_WARN)
			die(archive_error_string(ext));
	}
	archive_read_close(a);
	archive_read_free(a);
	archive_write_close(ext);
	archive_write_free(ext);
}

static char const * const tmpfs[] = {
    "fstype", "tmpfs", "fspath", "/rw"
};
static char const * const devfs[] = {
    "fstype", "devfs", "fspath", "/rw/dev"
};

int
main(int argc __unused, char *argv[])
{

	/* Prevent foot shooting. */
	if (getpid() != 1)
		return (1);

	if (modfind("tmpfs") == -1 && kldload("tmpfs") == -1)
		die("error loading tmpfs");

	/* Extract FreeBSD installation in a tmpfs. */
	domount(tmpfs, sizeof(tmpfs) / sizeof(char *));
	extract("/root.txz");
	domount(devfs, sizeof(devfs) / sizeof(char *));

	/* chroot() into system and continue boot process. */
	if (chroot("/rw") != 0)
		die("chroot");
	chdir("/");

	/* Execute the real /sbin/init. */
	execv(argv[0], argv);
	die("execv");
	return (1);
}
