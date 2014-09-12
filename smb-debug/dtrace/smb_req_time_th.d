#!/usr/sbin/dtrace -qs

/*
 * captures SMB requests took longer than specified time
 * user id: smb_request_t->uid_user->u_name
 * file: fid_ofile->f_node->vp->v_path
 *
 * Usage: ./smd_req_time_th.d 0   to use default 500 usecs threshold
 *        ./smd_req_time_th.d 50   to use default 50 msecs (50000 usecs) threshold
 */

BEGIN
{
        /* The default threshold is 500 usec */
        delaytime = $1 > 0 ? $1 * 1000 : 500;
        printf("\nWarnings for SMB requests with latency > %d usecs\n", delaytime);
}

fbt::smb1sr_work:entry
{ self->tr = 1; self->start = timestamp; self->sr = args[0]; }

fbt::smb_com_*:entry
/self->tr/ { self->func = probefunc; }

fbt::smb1sr_work:return
/self->tr && (timestamp/1000 - self->start/1000) > delaytime/
{
        self->vpath = self->sr->fid_ofile == NULL ? "dummy_file" :
            stringof(self->sr->fid_ofile->f_node->vp->v_path);

        self->uname = self->sr->uid_user->u_name == NULL ? "dummy_uid" :
            stringof(self->sr->uid_user->u_name);

        printf("%Y: %-25s %s  %s  %10d\n", walltimestamp,
            self->func, self->uname, self->vpath, timestamp/1000 - self->start/1000);
}

fbt::smb1sr_work:return
/self->tr/ { self->tr = 0; self->start = 0; self->sr = 0; self->func = 0; }
