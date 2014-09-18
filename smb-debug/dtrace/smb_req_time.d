#!/usr/sbin/dtrace -qs

/*
 * smb_req_time.d
 *
 * Returns the SMB requests that take longer than a specified time to complete.
 * The response time is indicative of the latency a user would experience
 * assuming no network latency.
 *
 * Usage: ./smd_req_time_th.d <threshold in ms>
 *
 * Tony Nguyen <tony.nguyen@nexenta.com>
 * William Kettler <william.kettler@nexenta.com>
 */

BEGIN
{
        /* The default threshold is 500 usec */
        delaytime = $1 > 0 ? $1 * 1000 : 500;
        printf("\nSMB requests with latency > %d usecs.\n\n", delaytime);

        /* SMB1 command codes */
        smb1_cmd_code[0x00] = "SmbCreateDirectory";
        smb1_cmd_code[0x01] = "SmbDeleteDirectory";
        smb1_cmd_code[0x02] = "SmbOpen";
        smb1_cmd_code[0x03] = "SmbCreate";
        smb1_cmd_code[0x04] = "SmbClose";
        smb1_cmd_code[0x05] = "SmbFlush";
        smb1_cmd_code[0x06] = "SmbDelete";
        smb1_cmd_code[0x07] = "SmbRename";
        smb1_cmd_code[0x08] = "SmbQueryInformation";
        smb1_cmd_code[0x09] = "SmbSetInformation";
        smb1_cmd_code[0x0A] = "SmbRead";
        smb1_cmd_code[0x0B] = "SmbWrite";
        smb1_cmd_code[0x0C] = "SmbLockByteRange";
        smb1_cmd_code[0x0D] = "SmbUnlockByteRange";
        smb1_cmd_code[0x0E] = "SmbCreateTemporary";
        smb1_cmd_code[0x0F] = "SmbCreateNew";
        smb1_cmd_code[0x10] = "SmbCheckDirectory";
        smb1_cmd_code[0x11] = "SmbProcessExit";
        smb1_cmd_code[0x12] = "SmbSeek";
        smb1_cmd_code[0x13] = "SmbLockAndRead";
        smb1_cmd_code[0x14] = "SmbWriteAndUnlock";
        smb1_cmd_code[0x1A] = "SmbReadRaw";
        smb1_cmd_code[0x1D] = "SmbWriteRaw";
        smb1_cmd_code[0x22] = "SmbSetInformation2";
        smb1_cmd_code[0x23] = "SmbQueryInformation2";
        smb1_cmd_code[0x24] = "SmbLockingX";
        smb1_cmd_code[0x25] = "SmbTransaction";
        smb1_cmd_code[0x26] = "SmbTransactionSecondary";
        smb1_cmd_code[0x27] = "SmbIoctl";
        smb1_cmd_code[0x2B] = "SmbEcho";
        smb1_cmd_code[0x2C] = "SmbWriteAndClose";
        smb1_cmd_code[0x2D] = "SmbOpenX";
        smb1_cmd_code[0x2E] = "SmbReadX";
        smb1_cmd_code[0x2F] = "SmbWriteX";
        smb1_cmd_code[0x31] = "SmbCloseAndTreeDisconnect";
        smb1_cmd_code[0x32] = "SmbTransaction2";
        smb1_cmd_code[0x33] = "SmbTransaction2Secondary";
        smb1_cmd_code[0x34] = "SmbFindClose2";
        smb1_cmd_code[0x70] = "SmbTreeConnect";
        smb1_cmd_code[0x71] = "SmbTreeDisconnect";
        smb1_cmd_code[0x72] = "SmbNegotiate";
        smb1_cmd_code[0x73] = "SmbSessionSetupX";
        smb1_cmd_code[0x74] = "SmbLogoffX";
        smb1_cmd_code[0x75] = "SmbTreeConnectX";
        smb1_cmd_code[0x80] = "SmbQueryInformationDisk";
        smb1_cmd_code[0x81] = "SmbSearch";
        smb1_cmd_code[0x82] = "SmbFind";
        smb1_cmd_code[0x83] = "SmbFindUnique";
        smb1_cmd_code[0x84] = "SmbFindClose";
        smb1_cmd_code[0xA0] = "SmbNtTransact";
        smb1_cmd_code[0xA1] = "SmbNtTransactSecondary";
        smb1_cmd_code[0xA2] = "SmbNtCreateX";
        smb1_cmd_code[0xA4] = "SmbNtCancel";
        smb1_cmd_code[0xA5] = "SmbNtRename";
        smb1_cmd_code[0xC0] = "SmbOpenPrintFile";
        smb1_cmd_code[0xC1] = "SmbWritePrintFile";
        smb1_cmd_code[0xC2] = "SmbClosePrintFile";
        smb1_cmd_code[0xC3] = "SmbGetPrintQueue";

        /* SMB2 command codes */
        smb2_cmd_code[0x00] = "smb2_negotiate";
        smb2_cmd_code[0x01] = "smb2_session_setup";
        smb2_cmd_code[0x02] = "smb2_logoff";
        smb2_cmd_code[0x03] = "smb2_tree_connect";
        smb2_cmd_code[0x04] = "smb2_tree_disconn";
        smb2_cmd_code[0x05] = "smb2_create";
        smb2_cmd_code[0x06] = "smb2_close";
        smb2_cmd_code[0x07] = "smb2_flush";
        smb2_cmd_code[0x08] = "smb2_read";
        smb2_cmd_code[0x09] = "smb2_write";
        smb2_cmd_code[0x0A] = "smb2_lock";
        smb2_cmd_code[0x0B] = "smb2_ioctl";
        smb2_cmd_code[0x0C] = "smb2_cancel";
        smb2_cmd_code[0x0D] = "smb2_echo";
        smb2_cmd_code[0x0E] = "smb2_query_dir";
        smb2_cmd_code[0x0F] = "smb2_change_notify";
        smb2_cmd_code[0x10] = "smb2_query_info";
        smb2_cmd_code[0x11] = "smb2_set_info";
        smb2_cmd_code[0x12] = "smb2_oplock_break_ack";
}

fbt::smb1sr_work:entry,
fbt::smb2sr_work:entry
{
    self->tr = 1;
    self->sr = args[0];
    self->start = timestamp;
}

fbt::smb1sr_work:return,
fbt::smb2sr_work:return
/self->tr/
{
    self->rtime = (timestamp - self->start) / 1000
}

/*
 * SMB1
 */

fbt::smb1sr_work:return
/self->tr && self->rtime > delaytime/
{
    self->cmd_string = smb1_cmd_code[self->sr->smb_com] != 0 ?
        smb1_cmd_code[self->sr->smb_com] : "Invalid";

    self->vpath = self->sr->fid_ofile == NULL ? "Unknown" :
        stringof(self->sr->fid_ofile->f_node->vp->v_path);

    self->uname = self->sr->uid_user->u_name == NULL ? "Unknown" :
        stringof(self->sr->uid_user->u_name);

    @smb1_rtime[self->cmd_string] = quantize(self->rtime);

    printf("%Y: %s %s %s %-10d\n", walltimestamp, self->cmd_string,
        self->uname, self->vpath, self->rtime);
}

/*
 * SMB2
 */

fbt::smb2sr_work:return
/self->tr && self->rtime > delaytime/
{
    self->cmd_string = smb2_cmd_code[self->sr->smb2_cmd_code] != 0 ?
        smb2_cmd_code[self->sr->smb2_cmd_code] : "Invalid";

    self->vpath = self->sr->fid_ofile == NULL ? "Unknown" :
        stringof(self->sr->fid_ofile->f_node->vp->v_path);

    self->uname = self->sr->uid_user->u_name == NULL ? "Unknown" :
        stringof(self->sr->uid_user->u_name);

    @smb2_rtime[self->cmd_string] = quantize(self->rtime);

    printf("%Y: %s %s %s %-10d\n", walltimestamp, self->cmd_string,
        self->uname, self->vpath, self->rtime);
}

fbt::smb1sr_work:return,
fbt::smb2sr_work:return
/self->tr/
{
    self->tr = 0;
    self->sr = 0;
    self->start = 0;
    self->cmd_string = 0;
    self->vpath = 0;
    self->uname = 0;
}

profile:::tick-60sec
{
    printa(@smb1_rtime);
    clear(@smb1_rtime);
    printa(@smb2_rtime);
    clear(@smb2_rtime);
}
