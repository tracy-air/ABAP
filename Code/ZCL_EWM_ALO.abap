class ZCL_EWM_ALO definition
  public
  final
  create public .

public section.
*"* public components of class ZCL_EWM_ALO
*"* do not include other source files here!!!

  class-methods WRITE_LOG
    importing
      !IV_EXTNUM type BALNREXT
      !IV_OBJECT type BALOBJ_D
      !IV_SUBOBJ type BALSUBOBJ
      !IT_LOGTABLE type BAPIRETTAB
    exporting
      value(ET_RETURN) type BAPIRETTAB
      value(ET_MSG_HNDL) type BAL_T_MSGH .
  class-methods POPULATE_MESSAGE
    importing
      !IV_TYPE type BAPI_MTYPE optional
      !IV_ID type SYMSGID optional
      !IV_NUMBER type SYMSGNO optional
      !IV_MESSAGE type BAPI_MSG optional
      !IV_MESSAGE_V1 type SYMSGV optional
      !IV_MESSAGE_V2 type SYMSGV optional
      !IV_MESSAGE_V3 type SYMSGV optional
      !IV_MESSAGE_V4 type SYMSGV optional
    returning
      value(RS_RETURN) type BAPIRET2 .
protected section.
*"* protected components of class ZCL_EWM_ALO
*"* do not include other source files here!!!
private section.
*"* private components of class ZCL_EWM_ALO
*"* do not include other source files here!!!
ENDCLASS.



CLASS ZCL_EWM_ALO IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_EWM_ALO=>POPULATE_MESSAGE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_TYPE                        TYPE        BAPI_MTYPE(optional)
* | [--->] IV_ID                          TYPE        SYMSGID(optional)
* | [--->] IV_NUMBER                      TYPE        SYMSGNO(optional)
* | [--->] IV_MESSAGE                     TYPE        BAPI_MSG(optional)
* | [--->] IV_MESSAGE_V1                  TYPE        SYMSGV(optional)
* | [--->] IV_MESSAGE_V2                  TYPE        SYMSGV(optional)
* | [--->] IV_MESSAGE_V3                  TYPE        SYMSGV(optional)
* | [--->] IV_MESSAGE_V4                  TYPE        SYMSGV(optional)
* | [<-()] RS_RETURN                      TYPE        BAPIRET2
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD populate_message.
*---------------------------------------------------------------------*
* Populate the messages into table.
*
*---------------------------------------------------------------------*
* CHANGE HISTORY
*---------------------------------------------------------------------*
* Date        |User ID   | Description
*---------------------------------------------------------------------*
*             |          |
*---------------------------------------------------------------------*

  DATA: lv_string TYPE string
      .

  CLEAR rs_return.
  rs_return-type   = iv_type.
  rs_return-id     = iv_id.
  rs_return-number = iv_number .

  IF iv_message IS NOT INITIAL.
    rs_return-message = iv_message.
  ELSE.
    MESSAGE ID iv_id TYPE iv_type NUMBER iv_number
       INTO lv_string
       WITH iv_message_v1 iv_message_v2 iv_message_v3 iv_message_v4.
    rs_return-message = lv_string.
  ENDIF.

  rs_return-message_v1 = iv_message_v1.
  rs_return-message_v2 = iv_message_v2.
  rs_return-message_v3 = iv_message_v3.
  rs_return-message_v4 = iv_message_v4.

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_EWM_ALO=>WRITE_LOG
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_EXTNUM                      TYPE        BALNREXT
* | [--->] IV_OBJECT                      TYPE        BALOBJ_D
* | [--->] IV_SUBOBJ                      TYPE        BALSUBOBJ
* | [--->] IT_LOGTABLE                    TYPE        BAPIRETTAB
* | [<---] ET_RETURN                      TYPE        BAPIRETTAB
* | [<---] ET_MSG_HNDL                    TYPE        BAL_T_MSGH
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD write_log.
*---------------------------------------------------------------------*
* Write application log into SLG1.
*- Function writes all aplication logs to database
*-  IV_LOGTABLE  => BAPIRETTAB table which contains all logs that will
*-                  be saved to database
*-  IV_LOGHANDLE => Application Log hande in which the logs will be
*-                  stored.
*---------------------------------------------------------------------*
* CHANGE HISTORY
*---------------------------------------------------------------------*
* Date        |User ID   | Description
*---------------------------------------------------------------------*
*             |          |
*---------------------------------------------------------------------*

  DATA: lt_loghandle  TYPE bal_t_logh
      , ls_loghandle  TYPE balloghndl
      , ls_logvalue   TYPE bapiret2
      , ls_retvalue   TYPE bapiret2
      , ls_balvalue   TYPE bal_s_msg
      , ls_logger     TYPE bal_s_log
      , ls_msg_hndl   TYPE balmsghndl
      .

  "Get logger informations.
  ls_logger-extnumber = iv_extnum.
  ls_logger-object    = iv_object.
  ls_logger-subobject = iv_subobj.

*--------------------------------------------------------------------
*- First create an application log
*--------------------------------------------------------------------
*--------------------------------------------------------------------
*- If the log is not yet created -> Create ne application log.
*--------------------------------------------------------------------
  IF ls_loghandle IS INITIAL.
    CALL FUNCTION 'BAL_LOG_CREATE'
      EXPORTING
        i_s_log                 = ls_logger
      IMPORTING
        e_log_handle            = ls_loghandle
      EXCEPTIONS
        log_header_inconsistent = 1
        OTHERS                  = 2.
*--------------------------------------------------------------------
*- If an error occurres then exit
*--------------------------------------------------------------------
    IF sy-subrc <> 0.
      CLEAR ls_retvalue.
      ls_retvalue-type       = sy-msgty.
      ls_retvalue-id         = sy-msgid.
      ls_retvalue-number     = sy-msgno.
      ls_retvalue-message_v1 = sy-msgv1.
      ls_retvalue-message_v2 = sy-msgv2.
      ls_retvalue-message_v3 = sy-msgv3.
      ls_retvalue-message_v4 = sy-msgv4.
      APPEND ls_retvalue TO et_return.
    ENDIF.
  ENDIF.
*--------------------------------------------------------------------
*- If the application log handle exists
*--------------------------------------------------------------------
  IF ls_loghandle IS NOT INITIAL.
*--------------------------------------------------------------------
*- Insert all logs into application table.
*--------------------------------------------------------------------
    LOOP AT it_logtable INTO ls_logvalue.
*--------------------------------------------------------------------
*- If the message type is initial then log an info log type ---------
*--------------------------------------------------------------------
      IF ls_logvalue-type IS INITIAL.
        ls_balvalue-msgty = 'I'.
      ELSE.
        ls_balvalue-msgty = ls_logvalue-type.
      ENDIF.
*--------------------------------------------------------------------
*- Set the message problclass (severenes)
*--------------------------------------------------------------------
      CASE ls_balvalue-msgty.
        WHEN 'S'.
          ls_balvalue-probclass = '4'.
        WHEN 'I'.
          ls_balvalue-probclass = '4'.
        WHEN 'W'.
          ls_balvalue-probclass = '3'.
        WHEN 'E'.
          ls_balvalue-probclass = '2'.
        WHEN 'A'.
          ls_balvalue-probclass = '1'.
        WHEN OTHERS.
          ls_balvalue-probclass = '4'.
      ENDCASE.
*--------------------------------------------------------------------
*- Add message into applicatio log.
*--------------------------------------------------------------------
      IF ls_logvalue-number IS NOT INITIAL AND ls_logvalue-id IS NOT INITIAL.
        ls_balvalue-msgno = ls_logvalue-number.
        ls_balvalue-msgid = ls_logvalue-id.
        ls_balvalue-msgv1 = ls_logvalue-message_v1.
        ls_balvalue-msgv2 = ls_logvalue-message_v2.
        ls_balvalue-msgv3 = ls_logvalue-message_v3.
        ls_balvalue-msgv4 = ls_logvalue-message_v4.
        ls_balvalue-detlevel = ls_logvalue-log_no.
*--------------------------------------------------------------------
        CLEAR ls_msg_hndl.
        CALL FUNCTION 'BAL_LOG_MSG_ADD'
          EXPORTING
            i_log_handle   = ls_loghandle
            i_s_msg        = ls_balvalue
          IMPORTING
            e_s_msg_handle = ls_msg_hndl
          EXCEPTIONS
            OTHERS         = 4.
        IF sy-subrc <> 0.
          CLEAR ls_retvalue.
          ls_retvalue-type       = sy-msgty.
          ls_retvalue-id         = sy-msgid.
          ls_retvalue-number     = sy-msgno.
          ls_retvalue-message_v1 = sy-msgv1.
          ls_retvalue-message_v2 = sy-msgv2.
          ls_retvalue-message_v3 = sy-msgv3.
          ls_retvalue-message_v4 = sy-msgv4.
          APPEND ls_retvalue TO et_return.
        ENDIF.
        APPEND ls_msg_hndl TO et_msg_hndl.
*--------------------------------------------------------------------
*- If the message parameter is set a simple text will be logged. ----
*--------------------------------------------------------------------
      ELSEIF ls_logvalue-message IS NOT INITIAL.
        CLEAR ls_msg_hndl.
        CALL FUNCTION 'BAL_LOG_MSG_ADD_FREE_TEXT'
          EXPORTING
            i_log_handle   = ls_loghandle
            i_msgty        = ls_balvalue-msgty
            i_probclass    = ls_balvalue-probclass
            i_text         = ls_logvalue-message
          IMPORTING
            e_s_msg_handle = ls_msg_hndl
          EXCEPTIONS
            OTHERS         = 4.
        IF sy-subrc <> 0.
          CLEAR ls_retvalue.
          ls_retvalue-type       = sy-msgty.
          ls_retvalue-id         = sy-msgid.
          ls_retvalue-number     = sy-msgno.
          ls_retvalue-message_v1 = sy-msgv1.
          ls_retvalue-message_v2 = sy-msgv2.
          ls_retvalue-message_v3 = sy-msgv3.
          ls_retvalue-message_v4 = sy-msgv4.
          APPEND ls_retvalue TO et_return.
        ENDIF.
        APPEND ls_msg_hndl TO et_msg_hndl.
      ENDIF.
    ENDLOOP.
*--------------------------------------------------------------------
*- Make lists of application log handles which will be saved to database
*--------------------------------------------------------------------
    APPEND ls_loghandle TO lt_loghandle.
*--------------------------------------------------------------------
*- Save all applicatio log to database.
*--------------------------------------------------------------------
    CALL FUNCTION 'BAL_DB_SAVE'
      EXPORTING
        i_t_log_handle   = lt_loghandle
      EXCEPTIONS
        log_not_found    = 1
        save_not_allowed = 2
        numbering_error  = 3
        OTHERS           = 4.
    IF sy-subrc <> 0.
      CLEAR ls_retvalue.
      ls_retvalue-type       = sy-msgty.
      ls_retvalue-id         = sy-msgid.
      ls_retvalue-number     = sy-msgno.
      ls_retvalue-message_v1 = sy-msgv1.
      ls_retvalue-message_v2 = sy-msgv2.
      ls_retvalue-message_v3 = sy-msgv3.
      ls_retvalue-message_v4 = sy-msgv4.
      APPEND ls_retvalue TO et_return.
    ENDIF.
  ENDIF.
*--------------------------------------------------------------------

  COMMIT WORK AND WAIT.

ENDMETHOD.
ENDCLASS.
