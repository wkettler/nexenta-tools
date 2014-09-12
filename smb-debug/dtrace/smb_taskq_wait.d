#!/usr/sbin/dtrace -qs

/*
 * smb_taskq_wait.d
 *
 * This script captures time requests spent waiting to be serviced, i.e.
 * waiting in taskq.
 *
 * Tony Nguyen <tony.nguyen@nexenta.com>
 *
 */

BEGIN
{
        /* The default threshold is 10 msec */
        delaytime = $1 > 0 ? $1 * 1000 : 10 * 1000;
        printf("\nWarnings for tasks whose queue times > %d usecs\n", delaytime);
}

fbt::smb1sr_work:entry
{ self->tr = 1; self->sr = args[0]; }

fbt::smb_com_*:entry
/self->tr/ { self->func = probefunc; }

fbt::smb1sr_work:return
/self->tr && (self->sr->sr_time_active/1000 - self->sr->sr_time_submitted/1000) > delaytime/
{
        printf("%Y: %s %-10d\n", walltimestamp, self->func,
            (self->sr->sr_time_active/1000 - self->sr->sr_time_submitted/1000));
}

fbt::smb1sr_work:return
/self->tr/ { self->tr = 0; self->sr = 0; self->func = 0; }
