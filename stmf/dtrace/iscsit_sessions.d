#!/usr/sbin/dtrace -qs

/*
 * iscsit_sessions.d
 *
 * Logs iSCSI target session state changes.
 *
 * William Kettler <william.kettler@nexenta.com>
 * Copyright 2014, Nexenta Systems, Inc.
 */

BEGIN
{
    /* Session States */
    state[0] = "SS_UNDEFINED";
    state[1] = "SS_Q1_FREE";
    state[2] = "SS_Q2_ACTIVE";
    state[3] = "SS_Q3_LOGGED_IN";
    state[4] = "SS_Q4_FAILED";
    state[5] = "SS_Q5_CONTINUE";
    state[6] = "SS_Q6_DONE";
    state[7] = "SS_Q7_ERROR";
    state[8] = "SS_MAX_STATE";

    /* Session Events */
    event[0] = "SE_UNDEFINED";
    event[1] = "SE_CONN_IN_LOGIN";          /* From login state machine */
    event[2] = "SE_CONN_LOGGED_IN";         /* FFP enabled client notification */
    event[3] = "SE_CONN_FFP_FAIL";          /* FFP disabled client notification */
    event[4] = "SE_CONN_FFP_DISABLE";       /* FFP disabled client notification */
    event[5] = "SE_CONN_FAIL";              /* Conn destroy client notification */
    event[6] = "SE_SESSION_CLOSE";          /* FFP disabled client notification */
    event[7] = "SE_SESSION_REINSTATE";      /* From login state machine */
    event[8] = "SE_SESSION_TIMEOUT";        /* Internal */
    event[9] = "SE_SESSION_CONTINUE";       /* From login state machine */
    event[10] = "SE_SESSION_CONTINUE_FAIL"; /* From login state machine? */
    event[11] = "SE_MAX_EVENT";

    printf("%-20s %-15s %-24s %s\n", "TIME", "STATE", "EVENT", "IQN");
}

sdt:iscsit:sess_sm_event_dispatch:session-event
{
    this->ist = (iscsit_sess_t *) arg0;
    this->ist_state = this->ist->ist_state;
    this->ist_initiator_name = this->ist->ist_initiator_name;

    this->ctx = (sess_event_ctx_t *) arg1;
    this->se_ctx_event = this->ctx->se_ctx_event;

    printf("%-20Y %-15s %-24s %s\n", walltimestamp,
        state[this->ist_state], event[this->se_ctx_event],
        stringof(this->ist_initiator_name));
}
