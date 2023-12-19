### **一.背景**：
- 在使用「全球集中付款」接口，发送数据后查询支付状态，若状态=23（准备上送影像系统），则需要将SAP服务器中的文件发给ICBC

### **二.方案**：
- 因ABAP自身对于SFTP的支持比较羸弱，故选择调用Linux系统命令行的方式实现SFTP

### **三.实现**：
1. 配置：
   - 1.1 生成ssh密钥（生成方式参考四中「文件服务接入指引」）ABAP用私钥签名，公钥需提供给工商银行配置，用于验签；
   - 1.2 SAP端用FILE事务代码创建需要使用到的文件路径；
   - 1.3 SAP端用SM49事务代码创建需要使用的系统命令，包括ls/mv/openssl/sh；
2. 脚本：
   ```
   #!/bin/sh
   HOST=106.120.68.125
   PORT=8001
   USER=****
   PASS=""
   LOCAL=/ZCH/ICBC/OUTBOUND/
   REMOTER=/EntTradeBGCommit/upload/
   BACKUP=/ZCH/ICBC/BACKUP/UPLOAD/
   lftp -u ${USER},${PASS} sftp://${HOST}:${PORT} <<EOF
   set sftp:auto-confirm yes
   set sftp:connect-program "ssh -a -x -i /home/chdadm/.ssh/id_rsa"
   local mirror -n    depth-first  ${LOCAL} ${BACKUP}
   mirror -n    depth-first   Remove-source-files -R  ${LOCAL}  ${REMOTER}   verbose
   EOF
   ```
3. ABAP代码：
   ```
   *&---------------------------------------------------------------------*
   *& Form frm_create_file
   *&---------------------------------------------------------------------*
   *& text
   *&---------------------------------------------------------------------*
   *&      --> <FS_PAYMENTDOC_ALV>
   *&---------------------------------------------------------------------*
   FORM frm_create_file USING ps_paymentdoc_alv STRUCTURE gw_paymentdoc_alv.
   
     TYPES:BEGIN OF ty_fileinfo,
             sourcefile     TYPE string,
             sourcefilesize TYPE string,
             signfile       TYPE string,
             signfilesize   TYPE string,
             remark         TYPE string,
           END OF ty_fileinfo.
   
     TYPES:BEGIN OF ty_data,
             fileinfo TYPE ty_fileinfo,
           END OF ty_data.
     DATA:ls_fileinfo TYPE ty_fileinfo,
          ls_data     TYPE ty_data.
   
     TYPES:BEGIN OF name_mapping,
             abap TYPE abap_compname,
             json TYPE string,
           END OF name_mapping .
     TYPES: name_mappings TYPE HASHED TABLE OF name_mapping WITH UNIQUE KEY abap.
     DATA: lt_name_mappings TYPE name_mappings,
           ls_name_mappings TYPE name_mapping.
   
     DATA:lv_file_len       TYPE i,
          lt_filecontenttab TYPE cpt_x255,
          ls_filecontenttab TYPE cps_x255,
          lv_file_dir       TYPE filename-fileintern,
          lv_source_dir     TYPE filename-fileintern,
          lv_outbound_dir   TYPE filename-fileintern,
          lv_out_file(120)  TYPE c,
          lv_openssl        LIKE sxpgcolist-name VALUE 'ZCH_OPENSSL',
          lv_command        TYPE string,
          lv_param          LIKE sxpgcolist-parameters,
          lv_file_name      TYPE string,
          lv_suffix         TYPE string,
          lv_file_origin    LIKE sxpgcolist-parameters,
          lv_file_sign      LIKE sxpgcolist-parameters,
          lv_status         LIKE extcmdexex-status,
          lv_exitcode       LIKE extcmdexex-exitcode,
          lt_exec_protocol  LIKE btcxpm OCCURS 0 WITH HEADER LINE,
          lv_lines          TYPE i,
          lv_filesize       TYPE i,
          lv_json           TYPE string.
   
     CLEAR:ls_fileinfo,ls_data,lv_file_len,lt_filecontenttab,lv_file_dir,lv_out_file,
           lv_command,lv_param,lv_file_name,lv_suffix,lv_file_origin,lv_file_sign,
           lv_status,lv_exitcode,lt_exec_protocol,lv_lines,lv_json,lv_filesize.
   
     lv_file_dir = 'ZCH_ICBC_PREPROCESS'.
     lv_source_dir = 'ZCH_ICBC_PREPROCESS'.
     lv_outbound_dir = 'ZCH_ICBC_OUTBOUND'.
   
     SELECT SINGLE * FROM zch_t_upbankfile INTO @DATA(ls_upbankfile)
       WHERE zsysno EQ @ps_paymentdoc_alv-zsysno
       AND file_created_flag EQ @abap_false.
   
     IF ls_upbankfile IS INITIAL.
       EXIT.
     ENDIF.
   
     cl_scp_change_db=>xstr_to_xtab( EXPORTING im_xstring = ls_upbankfile-file_content
                                     IMPORTING ex_xtab  = lt_filecontenttab
                                               ex_size = lv_file_len ).
   
     DESCRIBE TABLE lt_filecontenttab LINES lv_lines.
     lv_filesize = lv_lines * 255.
   
     CALL FUNCTION 'FILE_GET_NAME'
       EXPORTING
         client           = sy-mandt
         logical_filename = lv_file_dir
         operating_system = sy-opsys
       IMPORTING
         file_name        = lv_file_dir
       EXCEPTIONS
         file_not_found   = 1
         OTHERS           = 2.
   
     CONCATENATE lv_file_dir ls_upbankfile-file_name INTO lv_out_file.
   
     OPEN DATASET lv_out_file FOR OUTPUT IN BINARY MODE.
     IF sy-subrc = 0.
       LOOP AT lt_filecontenttab INTO ls_filecontenttab.
         TRANSFER ls_filecontenttab TO lv_out_file.
       ENDLOOP.
       CLOSE DATASET lv_out_file.
   
       SPLIT ls_upbankfile-file_name AT '.' INTO lv_file_name lv_suffix.
   
       lv_file_origin = lv_file_dir && ls_upbankfile-file_name.
       lv_file_sign = lv_file_dir && lv_file_name && '.sign'.
       lv_command = 'dgst -sha256 -sign /ZCH/ICBC/private2icbc.pem -out'.
   
       CONCATENATE lv_command lv_file_sign lv_file_origin INTO lv_param SEPARATED BY space.
   
       CALL FUNCTION 'SXPG_CALL_SYSTEM'
         EXPORTING
           commandname                = lv_openssl
           additional_parameters      = lv_param
         IMPORTING
           status                     = lv_status
           exitcode                   = lv_exitcode
         TABLES
           exec_protocol              = lt_exec_protocol
         EXCEPTIONS
           no_permission              = 1
           command_not_found          = 2
           parameters_too_long        = 3
           security_risk              = 4
           wrong_check_call_interface = 5
           program_start_error        = 6
           program_termination_error  = 7
           x_error                    = 8
           parameter_expected         = 9
           too_many_parameters        = 10
           illegal_command            = 11
           OTHERS                     = 12.
   
       ls_fileinfo-sourcefile = ls_upbankfile-file_name.
       ls_fileinfo-sourcefilesize = lv_filesize.
       CONDENSE ls_fileinfo-sourcefilesize NO-GAPS.
       ls_fileinfo-signfile = lv_file_name && '.sign'.
       ls_fileinfo-signfilesize = '256'.
       ls_data-fileinfo = ls_fileinfo.
   
       ls_name_mappings-abap = 'fileinfo'.
       ls_name_mappings-json = 'fileInfo'.
       INSERT ls_name_mappings INTO TABLE lt_name_mappings.CLEAR ls_name_mappings.
       ls_name_mappings-abap = 'sourcefile'.
       ls_name_mappings-json = 'sourceFile'.
       INSERT ls_name_mappings INTO TABLE lt_name_mappings.CLEAR ls_name_mappings.
       ls_name_mappings-abap = 'sourcefilesize'.
       ls_name_mappings-json = 'sourceFileSize'.
       INSERT ls_name_mappings INTO TABLE lt_name_mappings.CLEAR ls_name_mappings.
       ls_name_mappings-abap = 'signfile'.
       ls_name_mappings-json = 'signFile'.
       INSERT ls_name_mappings INTO TABLE lt_name_mappings.CLEAR ls_name_mappings.
       ls_name_mappings-abap = 'signfilesize'.
       ls_name_mappings-json = 'signFileSize'.
       INSERT ls_name_mappings INTO TABLE lt_name_mappings.CLEAR ls_name_mappings.
       ls_name_mappings-abap = 'remark'.
       ls_name_mappings-json = 'remark'.
       INSERT ls_name_mappings INTO TABLE lt_name_mappings.CLEAR ls_name_mappings.
   
       lv_json = zui2cl_json=>serialize( data = ls_data name_mappings = lt_name_mappings ).
   
       CLEAR lv_out_file.
       CONCATENATE lv_file_dir lv_file_name '.check' INTO lv_out_file.
       OPEN DATASET lv_out_file FOR OUTPUT IN TEXT MODE ENCODING UTF-8.
       IF sy-subrc = 0.
         TRANSFER lv_json TO lv_out_file.
         CLOSE DATASET lv_out_file.
       ENDIF.
   
       PERFORM frm_move_file USING lv_source_dir lv_outbound_dir ls_upbankfile-file_name.
   
       PERFORM frm_execute_sftp.
   
       ls_upbankfile-file_created_flag = abap_true.
       MODIFY zch_t_upbankfile FROM ls_upbankfile.
       IF sy-subrc EQ 0.
         COMMIT WORK AND WAIT.
       ELSE.
         ROLLBACK WORK.
       ENDIF.
   
     ENDIF.
   
   ENDFORM.
   *&---------------------------------------------------------------------*
   *& Form frm_move_file
   *&---------------------------------------------------------------------*
   *& text
   *&---------------------------------------------------------------------*
   *&      --> LV_SOURCE_DIR
   *&      --> LV_OUTBOUND_DIR
   *&      --> LS_UPBANKFILE_FILE_NAME
   *&---------------------------------------------------------------------*
   FORM frm_move_file USING pv_source_dir pv_outbound_dir pv_file_name.
   
     DATA:lv_filename    TYPE string,
          lv_origin_name TYPE string,
          lv_suffix      TYPE string,
          lv_subrc       LIKE sy-subrc.
   
     SPLIT pv_file_name AT '.' INTO lv_origin_name lv_suffix.
   
     CALL FUNCTION 'ZCH_MOVE_FILE'
       EXPORTING
         p_source_dir  = pv_source_dir
         p_file_name   = pv_file_name
         p_target_dir  = pv_outbound_dir
       IMPORTING
         p_subrc       = lv_subrc
       EXCEPTIONS
         get_file_name = 1
         OTHERS        = 2.
   
     lv_filename = lv_origin_name && '.sign'.
     CALL FUNCTION 'ZCH_MOVE_FILE'
       EXPORTING
         p_source_dir  = pv_source_dir
         p_file_name   = lv_filename
         p_target_dir  = pv_outbound_dir
       IMPORTING
         p_subrc       = lv_subrc
       EXCEPTIONS
         get_file_name = 1
         OTHERS        = 2.
   
     lv_filename = lv_origin_name && '.check'.
     CALL FUNCTION 'ZCH_MOVE_FILE'
       EXPORTING
         p_source_dir  = pv_source_dir
         p_file_name   = lv_filename
         p_target_dir  = pv_outbound_dir
       IMPORTING
         p_subrc       = lv_subrc
       EXCEPTIONS
         get_file_name = 1
         OTHERS        = 2.
   
   ENDFORM.
   *&---------------------------------------------------------------------*
   *& Form frm_execute_sftp
   *&---------------------------------------------------------------------*
   *& text
   *&---------------------------------------------------------------------*
   *& -->  p1        text
   *& <--  p2        text
   *&---------------------------------------------------------------------*
   FORM frm_execute_sftp.
   
     DATA:lv_commandname           LIKE  sxpgcolist-name,
          lv_additional_parameters LIKE  sxpgcolist-parameters,
          lv_status                LIKE extcmdexex-status,
          lv_exitcode              LIKE extcmdexex-exitcode,
          lt_exec_protocol         LIKE btcxpm OCCURS 0 WITH HEADER LINE.
   
     lv_commandname = 'ZCH_ICBC_SFTP'.
     lv_additional_parameters = '/ZCH/ICBC/icbc_up.sh'.
   
     CALL FUNCTION 'SXPG_COMMAND_EXECUTE'
       EXPORTING
         commandname                   = lv_commandname
         additional_parameters         = lv_additional_parameters
         operatingsystem               = 'Linux'
       IMPORTING
         status                        = lv_status
         exitcode                      = lv_exitcode
       TABLES
         exec_protocol                 = lt_exec_protocol
       EXCEPTIONS
         no_permission                 = 1
         command_not_found             = 2
         parameters_too_long           = 3
         security_risk                 = 4
         wrong_check_call_interface    = 5
         program_start_error           = 6
         program_termination_error     = 7
         x_error                       = 8
         parameter_expected            = 9
         too_many_parameters           = 10
         illegal_command               = 11
         wrong_asynchronous_parameters = 12
         cant_enq_tbtco_entry          = 13
         jobcount_generation_error     = 14
         OTHERS                        = 15.
     IF sy-subrc <> 0.
     ENDIF.
   
   ENDFORM.
   ```

### **四.参考资料**：
- 文件服务接入指引：https://open.icbc.com.cn/icbc/apip/faq_detail.html?id=10000000000000003000
