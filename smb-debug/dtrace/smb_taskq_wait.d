#!/usr/sbin/dtrace -s

/*
 * smb_taskq_wait.d
 *
 * This script captures time requests spend waiting to be serviced, i.e.
 * waiting in taskq.
 *
 * Tony Nguyen <tony.nguyen@nexenta.com>
 *
 */

fbt::smb1sr_work:entry
{ self->tr = 1; self->sr = args[0]; }

/* fbt::smb_com_nt_create_andx:entry */
fbt::smb_com_*:entry
/self->tr/
{
        self->func = probefunc;
}

fbt::smb1sr_work:return
/self->tr/
{
        @[self->func]= quantize((self->sr->sr_time_active - self->sr->sr_time_submitted)/1000);
        self->tr = 0; self->sr = 0; self->func = 0;
}

profile:::tick-5sec {printa(@); }
