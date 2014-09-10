#!/usr/sbin/dtrace -qs

/*
 * smb_kstat.d
 *
 * This script prints SMB kstats.
 *
 * Tony Nguyen <tony.nguyen@nexenta.com>
 *
 */

dtrace:::BEGIN
{
	/*
	r_iops = 1;
        rtask = 0;
        rqtime = 0;
        r_lu_xfer = 0;
        r_lport_xfer = 0;
	*/

	users=0; files=0; pipes=0; nreq1=0; nreq2=0;
	printf("users   files   pipes   nreqs");
}

fbt::smb_server_kstat_update:entry
{
	self->sv = (smb_server_t *) args[0]->ks_private;
	/* self->ksd = (smbsrv_kstat_t *) args[0]->ks_data; */

	/*@[self->sv->sv_users, self->sv->sv_files, self->sv->sv_pipes,
	  self->sv->nreqs] = count(); */

	users = self->sv->sv_users;
	files = self->sv->sv_files;
	pipes = self->sv->sv_pipes;
	nreq1 = nreq2; nreq2 = self->sv->sv_nreq;
}

profile:::tick-2sec {printf("\n%-7d %-7d %-7d %-10d", users, files, pipes, nreq2 - nreq1);}
