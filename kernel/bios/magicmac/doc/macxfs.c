/*
	if	(c1 == FA_ARCHIVE)			// !AK 19.2.99
	c2 &= FA_SUBDIR + FA_SYSTEM + FA_HIDDEN + FA_VOLUME;
 !TT 27.7.95: FA_SUBDIR-Abfrage ist unbedingt n�tig!
	xattr->size = (xattr->attr & FA_SUBDIR)? 0 : pb->hFileInfo.ioFlLgLen;	// Log. Laenge Data Fork