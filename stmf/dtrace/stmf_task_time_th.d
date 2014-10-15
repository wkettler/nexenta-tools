#!/usr/sbin/dtrace -qs

/*
 * stmf_task_time_th.d
 *
 * Print stmf operations which exceed a defined time threshold.
 *
 * lu_xfer (us)    - time spent to/from LU
 * lport_xfer (us) - time spent on the wire
 * qtime (us)      - time spent in the wait queue
 * task (us)       - time total
 *
 * Tony Nguyen <tony.nguyen@nexenta.com>
 *
 */

BEGIN
{
    /* The default delay time is 500 msec */
    delaytime = $1 > 0 ? $1 * 1000: 500 * 1000;
    printf("Warnings for I/O latency > %d usecs\n", delaytime);
}

/*
 * read task completed
 */
sdt:stmf:stmf_task_free:stmf-task-end
/((scsi_task_t *) arg0)->task_flags & 0x40 && (arg1 / 1000) > delaytime/
{
    this->task = (scsi_task_t *) arg0;
    this->task_lu = (stmf_lu_t *) this->task->task_lu;
    this->sl = (sbd_lu_t *) this->task_lu->lu_provider_private;
    this->itask = (stmf_i_scsi_task_t *) this->task->task_stmf_private;
    this->lport = this->task->task_lport;

    rtask = (arg1 / 1000);
    rqtime = (this->itask->itask_waitq_time / 1000);
    r_lu_xfer = (this->itask->itask_lu_read_time / 1000);
    r_lport_xfer = (this->itask->itask_lport_read_time / 1000);
    @r[stringof(this->sl->sl_name)] = quantize(rtask);

    printf("read (0x%x) %s: %d/%d/%d/%d (usecs)\n", this->task->task_cdb[0],
        stringof(this->sl->sl_name), r_lu_xfer, r_lport_xfer, rqtime, rtask);
}

/*
 * write task completed
 */
sdt:stmf:stmf_task_free:stmf-task-end
/((scsi_task_t *) arg0)->task_flags & 0x20 && (arg1 / 1000) > delaytime/
{
    this->task = (scsi_task_t *) arg0;
    this->task_lu = (stmf_lu_t *) this->task->task_lu;
    this->sl = (sbd_lu_t *) this->task_lu->lu_provider_private;
    this->itask = (stmf_i_scsi_task_t *) this->task->task_stmf_private;
    this->lport = this->task->task_lport;

    /* Save total time in usecs */
    wtask = (arg1 / 1000);
    wqtime = (this->itask->itask_waitq_time / 1000);
    w_lu_xfer =  (this->itask->itask_lu_write_time / 1000);
    w_lport_xfer = (this->itask->itask_lport_write_time / 1000);
    @w[stringof(this->sl->sl_name)] = quantize(wtask);

    printf("write (0x%x) %s: %d/%d/%d/%d (usecs)\n", this->task->task_cdb[0],
        stringof(this->sl->sl_name), w_lu_xfer, w_lport_xfer, wqtime, wtask);
}
