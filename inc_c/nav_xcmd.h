/***********************************************************************
*
* Nav_XCMD.h
*
* Navigation Services f�r MagiCMac
*
************************************************************************/

enum {
	xcmdGetFile		= 0,
	xcmdPutFile		= 1
};

typedef struct {
	short buflen;
	char *buf;
} NGetFileParm;

typedef struct {
	short buflen;
	char *buf;
} NPutFileParm;

/* EOF */
