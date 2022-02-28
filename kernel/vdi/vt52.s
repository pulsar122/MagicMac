SCROLL_LINE       EQU   320

/*
 * GEMDOS/BIOS/XBIOS
 */

Blitmode:
	move.w     (a0),d0                  /* Status nur erfragen? */
	bmi.s      Blitmode_nvdi
	lea.l      blitter,a0
	btst       #1,1(a0)                 /* Blitter vorhanden? */
	beq.s      Blitmode_nvdi
	and.w      #1,d0
	andi.w     #0xfffe,(a0)
	or.w       d0,(a0)                  /* neuen Blitterstatus setzen */

Blitmode_nvdi:
	move.w     blitter,d0               /* Blitter-Status */
	rte

vdi_cursor:
	tst.w      (V_HID_CNT).w            /* Cursor ein ? */
	bne.s      vdi_cursor_exit
	subq.b     #1,(V_CUR_CT).w          /* Cursor zeichnen ? */
	bne.s      vdi_cursor_exit
	move.b     (V_PERIOD).w,(V_CUR_CT).w   /* Blinkdauer */
	move.l     cursor_vbl_vec,-(sp)
vdi_cursor_exit:
	rts

/*
 * Bconout (RAWCON)
 */
vdi_rawout:
rawcon:
	lea.l      6(sp),a0                 /* Achtung: hier muss lea 6(sp) stehen, da MagiC diese Stelle evtl. ueberspringt */
	move.w     (a0),d1
	and.w      #0xff,d1
	movea.l    rawcon_vec,a0
	jmp        (a0)

/*
 * Bconout(CON)
 */
vdi_conout:
bconout:
	lea.l      6(sp),a0                 /* Achtung: hier muss lea 6(sp) stehen, da MagiC diese Stelle evtl. ueberspringt */
	move.w     (a0),d1
	and.w      #0xff,d1
	movea.l    (con_state).w,a0
	jmp        (a0)

/*
 * position cursor
 * inputs:
 * d0.w: column
 * d1.w: line
 * outputs:
 * a1 cursor address
 * d0-d2 are trashed
 */
set_cursor_xy:
	bsr        cursor_off
set_cur_clipx1:
	move.w     (V_CEL_MX).w,d2
	tst.w      d0
	bpl.s      set_cur_clipx2
	moveq.l    #0,d0
set_cur_clipx2:
	cmp.w      d2,d0
	ble.s      set_cur_clipy1
	move.w     d2,d0
set_cur_clipy1:
	move.w     (V_CEL_MY).w,d2
	tst.w      d1
	bpl.s      set_cur_clipy2
	moveq.l    #0,d1
set_cur_clipy2:
	cmp.w      d2,d1
	ble.s      set_cursor
	move.w     d2,d1
set_cursor:
	movem.w    d0-d1,(V_CUR_XY).w
	movea.l    (v_bas_ad).w,a1
	mulu.w     (V_CEL_WR).w,d1     /*  BUG: should use V_CEL_HT*BYTES_LIN instead */
	adda.l     d1,a1               /* line address */
	/* BUG: address calculation wrong for planes >= 16 */
	moveq.l    #1,d1
	and.w      d0,d1
	and.w      #0xfffe,d0
	mulu.w     (PLANES).w,d0
	add.w      d1,d0
	adda.w     d0,a1               /* cursor address */
	adda.w     (V_CUR_OF).w,a1     /* offset */
	move.l     a1,(V_CUR_AD).w
	bra.s      cursor_on

/*
 * turn text cursor off
 */
cursor_off:
	addq.w     #1,(V_HID_CNT).w    /* increment count */
	cmpi.w     #1,(V_HID_CNT).w
	bne.s      cursor_off_exit
	bclr       #CURSOR_STATE,(V_STAT_0).w /* cursor visible? */
	bne.s      cursor
cursor_off_exit:
	rts

/*
 * turn text cursor on
 */
cursor_on:
	cmpi.w     #1,(V_HID_CNT).w
	bcs.s      cursor_on_exit2
	bhi.s      cursor_on_exit1
	move.b     (V_PERIOD).w,(V_CUR_CT).w
	bsr.s      cursor
	bset       #CURSOR_STATE,(V_STAT_0).w /* cursor visible */
cursor_on_exit1:
	subq.w     #1,(V_HID_CNT).w
cursor_on_exit2:
	rts

vbl_cursor:
	btst       #CURSOR_BL,(V_STAT_0).w  /* blinking on? */
	beq.s      vbl_no_bl
	bchg       #CURSOR_STATE,(V_STAT_0).w
	bra.s      cursor
vbl_no_bl:
	bset       #CURSOR_STATE,(V_STAT_0).w
	beq.s      cursor
	rts

/*
 * draw text cursor
 * BUG: does not work for pixel-packed modes
 */
cursor:
	movem.l    d0-d2/a0-a2,-(sp)
	move.w     (PLANES).w,d0            /* plane counter */
	subq.w     #1,d0
	move.w     (V_CEL_HT).w,d2
	subq.w     #1,d2
	movea.l    (V_CUR_AD).w,a0          /* cursor address */
	movea.w    (BYTES_LIN).w,a2         /* bytes per line */
cursor_bloop:
	movea.l    a0,a1
	move.w     d2,d1
cursor_loop:
	not.b      (a1)
	adda.w     a2,a1                    /* next line */
	dbra       d1,cursor_loop
	addq.l     #2,a0                    /* next plane */
	dbra       d0,cursor_bloop          /* loop for planes */
	movem.l    (sp)+,d0-d2/a0-a2
cursor_exit:
	rts

/*
 * BEL, ring the bell
 */
vt_bel:
	btst       #2,(conterm).w           /* bell on? */
	beq.s      cursor_exit
	movea.l    (bell_hook).w,a0
	jmp        (a0)

/*
 * make sound for bell
 */
make_pling:
	pea.l      pling(pc)                /* Sequenz fuer Yamaha-Chip */
	move.w     #0x20,-(sp)              /* Dosound */
	trap       #14
	addq.l     #6,sp
	rts
pling:
	.dc.b 0x00,0x34,0x01,0x00,0x02,0x00,0x03,0x00,0x04,0x00,0x05,0x00,0x06,0x00,0x07,0xfe
	.dc.b 0x08,0x10,0x09,0x00,0x0a,0x00,0x0b,0x00,0x0c,0x10,0x0d,0x09,0xff,0x00


/*
 * BACKSPACE, one character back
 * d0 column
 * d1 line
 */
vt_bs:
	movem.w    (V_CUR_XY).w,d0-d1
	subq.w     #1,d0                    /* one column back */
	bra        set_cursor_xy

/*
 * HT
 * d0 column
 * d1 line
 */
vt_ht:
	andi.w     #0xfff8,d0               /* mask */
	addq.w     #8,d0                    /* next tab */
	bra        set_cursor_xy

/*
 * LINEFEED, next line
 * d1 line
 */
vt_lf:
	pea.l      cursor_on(pc)
	bsr        cursor_off
	sub.w      (V_CEL_MY).w,d1
	beq        scroll_up_page
	move.w     (V_CEL_WR).w,d1          /* d1: High-Word=0 ! (durch movem.w) BUG: should use V_CEL_HT*BYTES_LIN instead */
	add.l      d1,(V_CUR_AD).w          /* next line */
	addq.w     #1,(V_CUR_XY+2).w
	rts

/*
 * RETURN, start of line
 * d0 column
 */
vt_cr:
	bsr        cursor_off
	pea.l      cursor_on(pc)
	movea.l    (V_CUR_AD).w,a1          /* address of cursor */

/*
 * set cursor to start of line
 * inputs:
 * d0 column
 * a1 cursor address
 * outputs:
 * a1 new Cursor address
 * d0/d2 are trashed
 */
set_x0:
	move.w     (PLANES).w,d2
	btst       #0,d0                    /* word or byte position? */
	beq.s      set_x0_even
	subq.w     #1,d0
	mulu.w     d2,d0
	addq.l     #1,d0
	bra.s      set_x0_addr
set_x0_even:
	mulu.w     d2,d0
set_x0_addr:
	suba.l     d0,a1
	move.l     a1,(V_CUR_AD).w
	clr.w      (V_CUR_XY).w
	rts

/*
 * ESC
 */
vt_esc:
	move.l     #vt_esc_seq,(con_state).w /* jump address */
	rts

vt_control:
	cmpi.w     #27,d1
	beq.s      vt_esc
	subq.w     #7,d1
	subq.w     #6,d1
	bhi.s      vt_c_exit
	move.l     #vt_con,(con_state).w    /* jump address */
	add.w      d1,d1
	move.w     vt_c_tab(pc,d1.w),d2
	/* note: movem.w does sign extend, which is assumed in a lot of functions above/below */
	movem.w    (V_CUR_XY).w,d0-d1       /* text column/line */
	jmp        vt_c_tab(pc,d2.w)
vt_c_exit:
	rts

	.dc.w vt_bel-vt_c_tab    /* 7  BEL */
	.dc.w vt_bs-vt_c_tab     /* 8  BS */
	.dc.w vt_ht-vt_c_tab     /* 9  HT */
	.dc.w vt_lf-vt_c_tab     /* 10 LF */
	.dc.w vt_lf-vt_c_tab     /* 11 VT */
	.dc.w vt_lf-vt_c_tab     /* 12 FF */
vt_c_tab:
	.dc.w vt_cr-vt_c_tab     /* 13 CR */

vt_con:
	cmpi.w     #32,d1                   /* control character? */
	blt.s      vt_control
vt_rawcon:
	move.l     d3,-(sp)
	move.w     (V_CEL_HT).w,d0
	subq.w     #1,d0
	movea.l    (V_FNT_AD).w,a0          /* address of font image */
	movea.l    (V_CUR_AD).w,a1          /* address of cursor */
	move.w     (BYTES_LIN).w,a2         /* bytes pro line */
	adda.w     d1,a0                    /* address of character(-Offset) */
	move.w     (PLANES).w,d2
	subq.w     #1,d2                    /* plane counter */
	move.l     (V_COL_BG).w,d3          /* background color/foreground color */
	move.b     #4,(V_CUR_CT).w          /* increase cursor counter -> no cursor */
	bclr       #CURSOR_STATE,(V_STAT_0).w /* cursor not visible */
	btst       #CURSOR_INVERSE,(V_STAT_0).w /* invert ? */
	beq.s      vtc_char_loop
	swap       d3                       /* swap fore-/background color */
vtc_char_loop:
	movem.l    d0/a0-a1,-(sp)
	pea.l      vtc_char_next(pc)
	lsr.l      #1,d3                    /* foregound color? */
	bcc.s      vtc_char_fg0
	btst       #15,d3
	beq        vtc_charx
	bra        vtc_bg_black
vtc_char_fg0:
	btst       #15,d3                   /* backgound color? */
	bne        vtc_charrev
	bra        vtc_bg_white
vtc_char_next:
	movem.l    (sp)+,d0/a0-a1
	addq.l     #2,a1                    /* next plane */
	dbra       d2,vtc_char_loop
	move.l     (sp)+,d3
	move.w     (V_CUR_XY).w,d0
	cmp.w      (V_CEL_MX).w,d0          /* last column? */
	bge.s      vtc_l_column
	addq.w     #1,(V_CUR_XY).w          /* next column */
	lsr.w      #1,d0                    /* add planeoffset? */
	bcs.s      vtc_n_column
	addq.l     #1,(V_CUR_AD).w          /* next column */
	rts
vtc_n_column:
	subq.l     #1,a1
	move.l     a1,(V_CUR_AD).w
	rts
vtc_l_column:
	btst       #CURSOR_WRAP,(V_STAT_0).w /* wrapping on? */
	beq.s      vtc_con_exit1
	addq.w     #1,(V_HID_CNT).w         /* lock cursor */
	subq.w     #1,d0
	mulu.w     (PLANES).w,d0

	addq.w     #1,d0
	movea.l    (V_CUR_AD).w,a1
	suba.w     d0,a1
	move.l     a1,(V_CUR_AD).w          /* start of line */
	clr.w      (V_CUR_XY).w
	move.w     (V_CUR_XY+2).w,d1

	pea.l      vtc_con_exit2(pc)
	cmp.w      (V_CEL_MY).w,d1          /* last line? (scrolling) */
	bge        scroll_up_page
	addq.l     #4,sp                    /* adjust stack */
	adda.w     (V_CEL_WR).w,a1          /* next line  BUG: should use V_CEL_HT*BYTES_LIN instead */
	move.l     a1,(V_CUR_AD).w
	addq.w     #1,(V_CUR_XY+2).w
vtc_con_exit2:
	subq.w     #1,(V_HID_CNT).w         /* unlock cursor */
vtc_con_exit1:
	rts

vtc_charx:
	move.b     (a0),(a1)
	lea.l      256(a0),a0               /* next line of font BUG: use form_width */
	adda.w     a2,a1                    /* next screen line */
	dbra       d0,vtc_charx
	rts

vtc_charrev:
	move.b     (a0),d1
	not.b      d1
	move.b     d1,(a1)
	lea.l      256(a0),a0               /* next line of font BUG: use form_width */
	adda.w     a2,a1                    /* next screen line */
	dbra       d0,vtc_charrev
	rts

/*
/*
 * d0 (16 - charheight) * 2
 * a1 cursor address
 * a2 bytes pro line
 */
vtc_bg_white:
	moveq.l    #0,d1
	bra.s      vtc_bg
vtc_bg_black:
	moveq.l    #-1,d1
vtc_bg:
	move.b     d1,(a1)
	adda.w     a2,a1
	dbra       d0,vtc_bg
	rts

/*
 * handle ESC SEQUENCE
 */
vt_esc_seq:
	cmpi.w     #'Y',d1                  /* ESC Y ? */
	beq        vt_seq_Y
	move.w     d1,d2

	movem.w    (V_CUR_XY).w,d0-d1       /* text column/line */
	movea.l    (V_CUR_AD).w,a1          /* address of cursor */
	movea.w    (BYTES_LIN).w,a2         /* bytes per line */
	move.l     #vt_con,(con_state).w    /* jump address */

vt_seq_tA:
	subi.w     #'A',d2                  /* >=65 & <= 77 ? */
	cmpi.w     #12,d2
	bhi.s      vt_seq_tb
	add.w      d2,d2
	move.w     vt_seq_tab1(pc,d2.w),d2
	jmp        vt_seq_tab1(pc,d2.w)

vt_seq_tb:
	subi.w     #33,d2                   /* >=98 & <= 119 ? */
	cmpi.w     #21,d2
	bhi.s      vt_seq_exit
	add.w      d2,d2
	move.w     vt_seq_tab2(pc,d2.w),d2
	jmp        vt_seq_tab2(pc,d2.w)
/* Beendet bei falschen Opcode */
vt_seq_exit:
	rts

vt_seq_tab1:
	.dc.w vt_seq_A-vt_seq_tab1
	.dc.w vt_seq_B-vt_seq_tab1
	.dc.w vt_seq_C-vt_seq_tab1
	.dc.w vt_seq_D-vt_seq_tab1
	.dc.w vt_seq_E-vt_seq_tab1
	.dc.w vt_seq_exit-vt_seq_tab1
	.dc.w vt_seq_exit-vt_seq_tab1
	.dc.w vt_seq_H-vt_seq_tab1
	.dc.w vt_seq_I-vt_seq_tab1
	.dc.w vt_seq_J-vt_seq_tab1
	.dc.w vt_seq_K-vt_seq_tab1
	.dc.w vt_seq_L-vt_seq_tab1
	.dc.w vt_seq_M-vt_seq_tab1

vt_seq_tab2:
	.dc.w vt_seq_b-vt_seq_tab2
	.dc.w vt_seq_c-vt_seq_tab2
	.dc.w vt_seq_d-vt_seq_tab2
	.dc.w vt_seq_e-vt_seq_tab2
	.dc.w vt_seq_f-vt_seq_tab2
	.dc.w vt_seq_exit-vt_seq_tab2
	.dc.w vt_seq_exit-vt_seq_tab2
	.dc.w vt_seq_exit-vt_seq_tab2
	.dc.w vt_seq_j-vt_seq_tab2
	.dc.w vt_seq_k-vt_seq_tab2
	.dc.w vt_seq_l-vt_seq_tab2
	.dc.w vt_seq_exit-vt_seq_tab2
	.dc.w vt_seq_exit-vt_seq_tab2
	.dc.w vt_seq_o-vt_seq_tab2
	.dc.w vt_seq_p-vt_seq_tab2
	.dc.w vt_seq_q-vt_seq_tab2
	.dc.w vt_seq_exit-vt_seq_tab2
	.dc.w vt_seq_exit-vt_seq_tab2
	.dc.w vt_seq_exit-vt_seq_tab2
	.dc.w vt_seq_exit-vt_seq_tab2
	.dc.w vt_seq_v-vt_seq_tab2
	.dc.w vt_seq_w-vt_seq_tab2

/*
 * d0 text column
 * d1 text line
 * a1 cursor address
 * a2 bytes pro line
 */

/*
 * ALPHA CURSOR UP (VDI 5, ESCAPE 4)/ Cursor up (VT 52 ESC A)
 */
v_curup:
vt_seq_A:
	subq.w     #1,d1
	bra        set_cursor_xy

/*
 * ALPHA CURSOR DOWN (VDI 5,ESCAPE 5)/ Cursor down (VT52 ESC B)
 */
v_curdown:
vt_seq_B:
	addq.w     #1,d1
	bra        set_cursor_xy

/*
 * ALPHA CURSOR RIGHT (VDI 5, ESCAPE 6)/ Cursor right (VT52 ESC C)
 */
v_curright:
vt_seq_C:
	addq.w     #1,d0
	bra        set_cursor_xy

/*
 * ALPHA CURSOR LEFT (VDI 5, ESCAPE 7)/ Cursor left (VT52 ESC D)
 */
v_curleft:
vt_seq_D:
	subq.w     #1,d0
	bra        set_cursor_xy

/*
 * Clear screen (VT52 ESC E)
 */
vt_seq_E:
	bsr        cursor_off
	bsr        clear_screen
	bra.s      vt_seq_H_in

/*
 * HOME ALPHA CURSOR (VDI 5, ESCAPE 8)/ Home Cursor (VT52 ESC H)
 */
v_curhome:
vt_seq_H:
	bsr        cursor_off
vt_seq_H_in:
	clr.l      (V_CUR_XY).w
	movea.l    (v_bas_ad).w,a1
	adda.w     (V_CUR_OF).w,a1
	move.l     a1,(V_CUR_AD).w
	bra        cursor_on

/*
 * Cursor up and insert (VT52 ESC I)
 */
vt_seq_I:
	pea.l      cursor_on(pc)
	bsr        cursor_off
	subq.w     #1,d1                    /* cursor already in first line? */
	blt        scroll_down_page
	suba.w     (V_CEL_WR).w,a1          /* one line up  BUG: should use V_CEL_HT*BYTES_LIN instead */
	move.l     a1,(V_CUR_AD).w
	move.w     d1,(V_CUR_XY+2).w
	rts

/*
 * ERASE TO END OF ALPHA SRCEEN (VDI 5, ESCAPE 9)/ Erase to end of page (VT52 ESC J)
 */
v_eeos:
vt_seq_J:
	bsr.s      vt_seq_K                 /* clear to end of line */
	move.w     (V_CUR_XY+2).w,d1        /* text line */
	move.w     (V_CEL_MY).w,d2          /* last text line */
	sub.w      d1,d2                    /* number of lines to clear */
	beq.s      vt_seq_J_exit
	movem.l    d2-d7/a1-a6,-(sp)
	movea.l    (v_bas_ad).w,a1
	adda.w     (V_CUR_OF).w,a1
	addq.w     #1,d1
	mulu.w     (V_CEL_WR).w,d1          /* BUG: should use V_CEL_HT*BYTES_LIN instead */
	adda.l     d1,a1                    /* start address */
	move.w     d2,d7
	mulu.w     (V_CEL_HT).w,d7
	subq.w     #1,d7                    /* number of lines to clear - 1 */
	bra        clear_lines              /* clear lines/retore registers */
vt_seq_J_exit:
	rts

/*
 * ERASE TO END OF ALPHA TEXT LINE (VDI 5, ESCAPE 10)
 * Clear to end of line (VT52 ESC K)
 */
v_eeol:
vt_seq_K:
	bsr        cursor_off
	move.w     (V_CEL_MX).w,d2
	sub.w      d0,d2                    /* number of lines to clear */
	bsr        clear_line_part
	bra        cursor_on

/*
 * Insert line (VT52 ESC L)
 */
vt_seq_L:
	pea.l      cursor_on(pc)
	bsr        cursor_off
	bsr        set_x0                   /* set cursor to start of line */
	movem.l    d2-d7/a1-a6,-(sp)        /* save registers */

	move.w     (V_CEL_MY).w,d7
	move.w     d7,d5
	sub.w      d1,d7                    /* last line? */
	beq.s      vt_seq_L_exit
	move.w     (V_CEL_WR).w,d6          /* bytes per text line BUG: should use V_CEL_HT*BYTES_LIN instead */
	mulu.w     d6,d5
	movea.l    (v_bas_ad).w,a0
	adda.w     (V_CUR_OF).w,a0
	adda.l     d5,a0                    /* source address */
	lea.l      0(a0,d6.w),a1            /* destination address */
	mulu.w     d6,d7                    /* number of lines */
	divu.w     #SCROLL_LINE,d7          /* 320 byte counter ; BUG: WTF */
	subq.w     #1,d7                    /* for dbf */
	bsr        scroll_down
vt_seq_L_exit:
	movea.l    (V_CUR_AD).w,a1          /* address of cursor */
	bra        clear_line2              /* clear lines/restore registers */

/*
 * Delete Line (VT52 ESC M)
 */
vt_seq_M:
	pea.l      cursor_on(pc)
	bsr        cursor_off
	bsr        set_x0                   /* set cursor to start of line */
	movem.l    d2-d7/a1-a6,-(sp)        /* save registers */
	move.w     (V_CEL_MY).w,d7
	sub.w      d1,d7                    /* only last line to clear? */
	beq        clear_line2
	move.w     (V_CEL_WR).w,d6          /* bytes per text line BUG: should use V_CEL_HT*BYTES_LIN instead */
	lea.l      0(a1,d6.w),a0            /* source address */
	mulu.w     d6,d7                    /* number of bytes */
	divu.w     #SCROLL_LINE,d7          /* 320 byte counter; BUG: WTF */
	subq.w     #1,d7                    /* for dbf */
	bra        scroll_up2               /* scroll/clear/register/cursor on */

/*
 * Set cursor position (VT52 ESC Y)
 */
vt_seq_Y:
	move.l     #vt_set_y,(con_state).w  /* jump address */
	rts

/* set y-coordinate */
vt_set_y:
	subi.w     #32,d1
	move.w     (V_CUR_XY).w,d0
	move.l     #vt_set_x,(con_state).w  /* jump address */
	bra        set_cursor_xy

/* set x-coordinate */
vt_set_x:
	subi.w     #32,d1
	move.w     d1,d0
	move.w     (V_CUR_XY+2).w,d1
	move.l     #vt_con,(con_state).w    /* jump address */
	bra        set_cursor_xy

/*
 * Foreground color (VT52 ESC b)
 */
vt_seq_b:
	move.l     #vt_set_b,(con_state).w
	rts
vt_set_b:
	moveq.l    #15,d0
	and.w      d0,d1                    /* mask color */
	cmp.w      d0,d1
	bne.s      vt_set_b_exit
	moveq.l    #-1,d1
vt_set_b_exit:
	move.w     d1,(V_COL_FG).w          /* foreground color */
	move.l     #vt_con,(con_state).w    /* jump address */
	rts

/*
 * Background color (VT52 ESC c)
 */
vt_seq_c:
	move.l     #vt_set_c,(con_state).w
	rts
vt_set_c:
	moveq.l    #15,d0
	and.w      d0,d1                    /* mask color */
	cmp.w      d0,d1
	bne.s      vt_set_c_exit
	moveq.l    #-1,d1
vt_set_c_exit:
	move.w     d1,(V_COL_BG).w          /* foregournd color */
	move.l     #vt_con,(con_state).w    /* jump address */
	rts

/*
 * Erase to start of page (VT52 ESC d)
 */
vt_seq_d:
	bsr.s      vt_seq_o                 /* clear to beginning of line */
	move.w     (V_CUR_XY+2).w,d1        /* text line */
	beq.s      vt_seq_d_exit
	movem.l    d2-d7/a1-a6,-(sp)
	mulu.w     (V_CEL_HT).w,d1
	move.w     d1,d7
	subq.w     #1,d7                    /* line counter */
	movea.l    (v_bas_ad).w,a1
	adda.w     (V_CUR_OF).w,a1          /* start of page */
	bra        clear_lines              /* clear/restore registers */
vt_seq_d_exit:
	rts

/*
 * Show cursor (VT52 ESC e)
 */
vt_seq_e:
	tst.w      (V_HID_CNT).w
	beq.s      vt_seq_e_exit
	move.w     #1,(V_HID_CNT).w
	bra        cursor_on
vt_seq_e_exit:
	rts

/*
 * Hide cursor (VT52 ESC f)
 */
vt_seq_f:
	bra        cursor_off

/*
 * Save cursor (VT52 ESC j)
 */
vt_seq_j:
	bset       #CURSOR_SAVED,(V_STAT_0).w
	move.l     (V_CUR_XY).w,(RETSAV).w
	rts

/*
 * Restore cursor (VT52 ESC k)
 */
vt_seq_k:
	movem.w    (RETSAV).w,d0-d1
	bclr       #CURSOR_SAVED,(V_STAT_0).w
	bne        set_cursor_xy
	moveq.l    #0,d0
	moveq.l    #0,d1
	bra        set_cursor_xy

/*
 * Erase line (VT52 ESC l)
 */
vt_seq_l:
	bsr        cursor_off
	bsr        set_x0                   /* start of line */
	bsr        clear_line
	bra        cursor_on

/*
 * Erase to line start (VT52 ESC o)
 */
vt_seq_o:
	move.w     d0,d2
	subq.w     #1,d2                    /* number of columns - 1 */
	bmi.s      vt_seq_o_exit
	movea.l    (v_bas_ad).w,a1
	adda.w     (V_CUR_OF).w,a1
	mulu.w     (V_CEL_WR).w,d1          /* BUG: should use V_CEL_HT*BYTES_LIN instead */
	adda.l     d1,a1                    /* start of line */
	bra        clear_line_part
vt_seq_o_exit:
	rts

/*
 * REVERSE VIDEO ON (VDI 5, ESCAPE 13)/Reverse video (VT52 ESC p)
 */
v_rvon:
vt_seq_p:
	bset       #CURSOR_INVERSE,(V_STAT_0).w
	rts

/*
 * REVERSE VIDEO OFF (VDI 5, ESCAPE 14)/Normal Video (VT52 ESC q)
 */
v_rvoff:
vt_seq_q:
	bclr       #CURSOR_INVERSE,(V_STAT_0).w
	rts

/*
 * Wrap at end of line (VT52 ESC v)
 */
vt_seq_v:
	bset       #CURSOR_WRAP,(V_STAT_0).w
	rts

/*
 * Discard end of line (VT52 ESC w)
 */
vt_seq_w:
	bclr       #CURSOR_WRAP,(V_STAT_0).w
	rts

scroll_up_page:
	movem.l    d2-d7/a1-a6,-(sp)
	movea.l    (v_bas_ad).w,a1
	adda.w     (V_CUR_OF).w,a1
	movea.l    a1,a0
	move.w     (V_CEL_WR).w,d7          /* bytes per text line BUG: should use V_CEL_HT*BYTES_LIN instead */
	adda.w     d7,a0
	mulu.w     (V_CEL_MY).w,d7          /* bytes to copy */
	divu.w     #SCROLL_LINE,d7          /*  BUG: WTF */
	subq.w     #1,d7                    /* for dbf */
scroll_up2:
	pea.l      clear_line2(pc)
scroll_up:
	movem.l    (a0)+,d2-d6/a2-a6
	movem.l    d2-d6/a2-a6,(a1)
	movem.l    (a0)+,d2-d6/a2-a6
	movem.l    d2-d6/a2-a6,40(a1)
	lea.l      80(a1),a1
	movem.l    (a0)+,d2-d6/a2-a6
	movem.l    d2-d6/a2-a6,(a1)
	movem.l    (a0)+,d2-d6/a2-a6
	movem.l    d2-d6/a2-a6,40(a1)
	lea.l      80(a1),a1
	movem.l    (a0)+,d2-d6/a2-a6
	movem.l    d2-d6/a2-a6,(a1)
	movem.l    (a0)+,d2-d6/a2-a6
	movem.l    d2-d6/a2-a6,40(a1)
	lea.l      80(a1),a1
	movem.l    (a0)+,d2-d6/a2-a6
	movem.l    d2-d6/a2-a6,(a1)
	movem.l    (a0)+,d2-d6/a2-a6
	movem.l    d2-d6/a2-a6,40(a1)
	lea.l      80(a1),a1
	dbf        d7,scroll_up
	swap       d7
	lsr.w      #1,d7
	dbf        d7,scroll_upw
	rts
scroll_upw:
	move.w     (a0)+,(a1)+
	dbf        d7,scroll_upw
	rts

scroll_down_page:
	movem.l    d2-d7/a1-a6,-(sp)
	movea.l    (v_bas_ad).w,a0
	adda.w     (V_CUR_OF).w,a0
	move.w     (V_CEL_WR).w,d6          /* bytes per text line BUG: should use V_CEL_HT*BYTES_LIN instead */
	move.w     (V_CEL_MY).w,d7          /* number of lines to copy */
	mulu.w     d6,d7                    /* number of bytes to copy */
	lea.l      -40(a0,d7.l),a0          /* end of 2nd last text line; BUG: WTF */
	lea.l      40(a0,d6.w),a1           /* end of last text line */
	divu.w     #SCROLL_LINE,d7          /*  BUG: WTF */
	subq.w     #1,d7                    /* for dbf */
	bsr.s      scroll_down2
	movea.l    (v_bas_ad).w,a1
	adda.w     (V_CUR_OF).w,a1
	bra.s      clear_line2
scroll_down:
	lea.l      -40(a0),a0
scroll_down2:
	movem.l    (a0),d2-d6/a2-a6
	movem.l    d2-d6/a2-a6,-(a1)
	movem.l    -40(a0),d2-d6/a2-a6
	movem.l    d2-d6/a2-a6,-(a1)
	lea.l      -80(a0),a0
	movem.l    (a0),d2-d6/a2-a6
	movem.l    d2-d6/a2-a6,-(a1)
	movem.l    -40(a0),d2-d6/a2-a6
	movem.l    d2-d6/a2-a6,-(a1)
	lea.l      -80(a0),a0
	movem.l    (a0),d2-d6/a2-a6
	movem.l    d2-d6/a2-a6,-(a1)
	movem.l    -40(a0),d2-d6/a2-a6
	movem.l    d2-d6/a2-a6,-(a1)
	lea.l      -80(a0),a0
	movem.l    (a0),d2-d6/a2-a6
	movem.l    d2-d6/a2-a6,-(a1)
	movem.l    -40(a0),d2-d6/a2-a6
	movem.l    d2-d6/a2-a6,-(a1)
	lea.l      -80(a0),a0
	dbf        d7,scroll_down2
	swap       d7
	lea.l      40(a0),a0                /* for correction of -40 */
	lsr.w      #1,d7
	dbf        d7,scroll_downw
	rts
scroll_downw:
	move.w     -(a0),-(a1)
	dbf        d7,scroll_downw
	rts


/*
 * Inputs:
 * a1 address of line
 */
clear_line:
	movem.l    d2-d7/a1-a6,-(sp)
clear_line2:
	move.w     (V_CEL_HT).w,d7
	subq.w     #1,d7
clear_lines:
	move.w     (V_CEL_MX).w,d5
	addq.w     #1,d5
	move.w     (V_COL_BG).w,d6
	movea.w    (BYTES_LIN).w,a2
	move.w     (PLANES).w,d2
	cmp.w      #8,d2                    /* more than 8 planes? */
	bgt        clear_line_uni
	add.w      d2,d2
	move.w     clear_tab(pc,d2.w),d2
	jmp        clear_tab(pc,d2.w)

clear_tab:
	.dc.w clear_lines_ex-clear_tab
	.dc.w clear_mono-clear_tab
	.dc.w clear_color2-clear_tab
	.dc.w clear_lines_ex-clear_tab
	.dc.w clear_color4-clear_tab
	.dc.w clear_lines_ex-clear_tab
	.dc.w clear_lines_ex-clear_tab
	.dc.w clear_lines_ex-clear_tab
	.dc.w clear_color8-clear_tab

clear_mono:
	moveq.l    #0,d2
	lsr.w      #1,d6
	negx.l     d2                       /* either black or white */
	suba.w     d5,a2
	subq.w     #4,d5
	lsr.w      #2,d5                    /* /4 */
	bcc.s      clear_mono2
	lea.l      clear_scr_word(pc),a3
	move.w     d5,d6
	lsr.w      #7,d5                    /* /128 counter */

	not.w      d6
	and.w      #0x007f,d6
	add.w      d6,d6
	lea.l      clear_scr_mono(pc,d6.w),a4 /* jump address */
	move.w     d5,d6
	jmp        (a3)
clear_mono2:
	move.w     d5,d6
	lsr.w      #7,d5                    /* /128 counter */
	not.w      d6
	and.w      #0x007f,d6
	add.w      d6,d6
	lea.l      clear_scr_mono(pc,d6.w),a3 /* jump address */
/*
 * d5 counter inside line
 * d7 line counter
 * a2 offset to next line
 * a3 jump address
 */
clear_scrm_loop:
	move.w     d5,d6
	jmp        (a3)
clear_scr_word:
	move.w     d2,(a1)+
	jmp        (a4)
clear_scr_mono:
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	move.l     d2,(a1)+
	dbf        d6,clear_scr_mono
	adda.w     a2,a1                    /* next line */
	dbf        d7,clear_scrm_loop
clear_lines_ex:
	movem.l    (sp)+,d2-d7/a1-a6
	rts

clear_color2:
	add.w      d5,d5
	moveq.l    #0,d2
	lsr.w      #1,d6
	negx.w     d2                       /* either black or white */
	swap       d2
	lsr.w      #1,d6
	negx.w     d2                       /* either black or white */
clear_regs2:
	move.l     d2,d3
clear_regs4:
	move.l     d2,d4
	movea.l    d3,a4
clear_regs8:
	suba.w     d5,a2
	subq.w     #1,d5
	lsr.w      #2,d5                    /* /4 */
	move.w     d5,d6
	lsr.w      #7,d5                    /* /128 counter */
	not.w      d6
	and.w      #0x007f,d6
	add.w      d6,d6
	lea.l      clear_scr_line(pc,d6.w),a3 /* jump address */
/*
 * d5 counter inside line
 * d7 line counter
 * a2 offset to next line
 * a3 jump address
 */
clear_scr_loop:
	move.w     d5,d6
	jmp        (a3)

clear_scr_line:
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	move.l     d2,(a1)+
	move.l     d3,(a1)+
	move.l     d4,(a1)+
	move.l     a4,(a1)+
	dbf        d6,clear_scr_line
	adda.w     a2,a1                    /* next line */
	dbf        d7,clear_scr_loop
	movem.l    (sp)+,d2-d7/a1-a6
	rts

clear_color4:
	add.w      d5,d5
	add.w      d5,d5
	moveq.l    #0,d2
	moveq.l    #0,d3
	lsr.w      #1,d6
	negx.w     d2                       /* either black or white */
	swap       d2
	lsr.w      #1,d6

	negx.w     d2                       /* either black or white */
	lsr.w      #1,d6
	negx.w     d3                       /* either black or white */
	swap       d3
	lsr.w      #1,d6
	negx.w     d3                       /* either black or white */
	bra        clear_regs4

clear_color8:
	moveq.l    #0,d2
	moveq.l    #0,d3
	moveq.l    #0,d4
	moveq.l    #0,d5
	lsr.w      #1,d6
	negx.w     d2                       /* either black or white */
	swap       d2
	lsr.w      #1,d6
	negx.w     d2                       /* either black or white */
	lsr.w      #1,d6
	negx.w     d3                       /* either black or white */
	swap       d3
	lsr.w      #1,d6
	negx.w     d3                       /* either black or white */
	lsr.w      #1,d6
	negx.w     d4                       /* either black or white */
	swap       d4
	lsr.w      #1,d6
	negx.w     d4                       /* either black or white */
	lsr.w      #1,d6
	negx.w     d5                       /* either black or white */
	swap       d5
	lsr.w      #1,d6
	negx.w     d5                       /* either black or white */
	movea.l    d5,a4
	move.w     (V_CEL_MX).w,d5
	addq.w     #1,d5
	lsl.w      #3,d5
	bra        clear_regs8

clear_line_uni:
	addq.w     #1,d7                    /* line counter */
	mulu.w     (BYTES_LIN).w,d7
	lsr.l      #5,d7
	subq.l     #1,d7
	moveq.l    #-1,d6                   /* BUG: always clears to white, does not use background color */
clear_uni_loop:
	move.l     d6,(a1)+
	move.l     d6,(a1)+
	move.l     d6,(a1)+
	move.l     d6,(a1)+
	move.l     d6,(a1)+
	move.l     d6,(a1)+
	move.l     d6,(a1)+
	move.l     d6,(a1)+
	subq.l     #1,d7
	bpl.s      clear_uni_loop
	movem.l    (sp)+,d2-d7/a1-a6
	rts

/*
 * clear screen
 * inputs:
 * -
 * outputs:
 * all registers preserved
 */
clear_screen:
	movem.l    d2-d7/a1-a6,-(sp)
	move.w     (V_CEL_MY).w,d7          /* number of textlines -1 */
	addq.w     #1,d7
	mulu.w     (V_CEL_HT).w,d7
	subq.w     #1,d7                    /* number of lines -1 */
	movea.l    (v_bas_ad).w,a1
	adda.w     (V_CUR_OF).w,a1          /* start address */
	bra        clear_lines

/*
 * clear part of a line
 * inputs:
 * d2.w number of columns -1
 * a1.l address
 * a2.w bytes per line
 * outputs:
 * d0-d2/a0-a1 are trashed
 */
clear_line_part:
	movem.l    d3-d6/a3-a4,-(sp)
	move.w     (V_COL_BG).w,d4          /* background color */
	move.w     (PLANES).w,d5
	move.w     d5,d6
	add.w      d5,d5                    /* plane offset */
	subq.w     #1,d6                    /* plane counter */
	movea.l    a1,a3
clear_lp_bloop:
	move.w     d2,d3
	movea.l    a3,a0
	lea.l      vtc_bg_white(pc),a4
	lsr.w      #1,d4
	bcc.s      clear_lp_loop
	lea.l      vtc_bg_black(pc),a4
clear_lp_loop:
	movea.l    a0,a1
	move.w     (V_CEL_HT).w,d0
	subq.w     #1,d0                    /* number of lines - 1 */
	jsr        (a4)
	addq.l     #1,a0
	move.l     a0,d1
	lsr.w      #1,d1
	bcs.s      clear_lp_dbf
	subq.l     #2,a0
	adda.w     d5,a0
clear_lp_dbf:
	dbf        d3,clear_lp_loop
	addq.l     #2,a3                    /* next plane */
	dbf        d6,clear_lp_bloop
	movem.l    (sp)+,d3-d6/a3-a4
	rts
