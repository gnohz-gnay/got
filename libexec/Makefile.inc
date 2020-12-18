.include "../Makefile.inc"

.if "${GOT_RELEASE}" == "Yes"
BINDIR = ${PREFIX}/libexec
.else
BINDIR = ${PREFIX}/bin
.endif

MAN =
