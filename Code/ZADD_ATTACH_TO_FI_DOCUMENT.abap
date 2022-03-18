*"添加附件到会计凭证

FUNCTION z_pv_add_attach_to_fi_document.
*"----------------------------------------------------------------------
*"*"局部接口：
*"  IMPORTING
*"     VALUE(IV_DATASET) TYPE  STRING
*"     VALUE(IV_BUKRS) TYPE  BUKRS
*"     VALUE(IV_BELNR) TYPE  BELNR_D
*"     VALUE(IV_GJAHR) TYPE  GJAHR
*"  TABLES
*"      ET_RETURN TYPE  BAPIRET1_TAB
*"----------------------------------------------------------------------

  INCLUDE:<cntn01>.

  DATA:ls_return TYPE LINE OF bapiret1_tab,
       l_belnr TYPE belnr_d.

  DATA:subrc TYPE sysubrc,
       filelength TYPE i,
       documentsize TYPE i VALUE 0,
       binary_tab TYPE solix OCCURS 0,
       binary_line TYPE solix.

  DATA:lv_path TYPE string,
       lv_filename TYPE string,
       lv_extension TYPE string.


  DATA:lv_object TYPE swc_object,
       obj_rolea TYPE borident,
       obj_roleb TYPE borident,
       binrel TYPE gbinrel,
       binrel_attrib TYPE STANDARD TABLE OF brelattr.
  DATA lo_obj_head TYPE REF TO cl_bcs_objhead.

  IF iv_dataset IS INITIAL OR iv_bukrs IS INITIAL
    OR iv_belnr IS INITIAL OR iv_gjahr IS INITIAL.
    ls_return-type = 'E'.
    ls_return-message = text-e01.
    APPEND ls_return TO et_return.
    RETURN.
  ENDIF.

*检查会计凭证是否存在
  SELECT SINGLE belnr INTO l_belnr FROM bkpf
    WHERE bukrs = iv_bukrs
    AND belnr = iv_belnr
    AND gjahr = iv_gjahr.
  IF l_belnr IS INITIAL.
    ls_return-type = 'E'.
    ls_return-message = text-e02 && iv_belnr.
    APPEND ls_return TO et_return.
    RETURN.
  ENDIF.

  OPEN DATASET iv_dataset FOR INPUT IN BINARY MODE.
  IF sy-subrc NE 0.
    ls_return-type = 'E'.
    ls_return-message = text-e03 && iv_dataset.
    APPEND ls_return TO et_return.
    RETURN.
  ELSE.
*读取文件到二进制内表
    WHILE subrc = 0.
      filelength = 0.

      READ DATASET iv_dataset INTO binary_line ACTUAL LENGTH filelength.
      subrc = sy-subrc.

      CHECK filelength > 0.

      documentsize = documentsize + filelength.

      APPEND binary_line TO binary_tab.
      CLEAR binary_line.
    ENDWHILE.

    CLOSE DATASET iv_dataset.

*拆分文件名和后缀
    lv_path = iv_dataset.
    CALL FUNCTION 'CRM_EMAIL_SPLIT_FILENAME'
      EXPORTING
        iv_path      = lv_path
      IMPORTING
        ev_filename  = lv_filename
        ev_extension = lv_extension.
    lv_filename = lv_filename && '.' && lv_extension.
* 将电子回单文件关联至收货凭证附件
    swc_container      lv_container.
* 将文件名添加到附件的文件名中
    lo_obj_head = cl_bcs_objhead=>create( ).
    lo_obj_head->set_filename( lv_filename ).
    swc_set_table lv_container  'DOCUMENTHEADER' lo_obj_head->mt_objhead.

    swc_create_object  lv_object     'MESSAGE'       ''.
    swc_set_element    lv_container  'NO_DIALOG'     'X'.
    swc_set_element    lv_container  'DOCUMENTTITLE' lv_filename.
    swc_set_table      lv_container  'Content_Hex'   binary_tab.
    swc_set_element    lv_container  'DOCUMENTTYPE'  lv_extension.
    swc_set_element    lv_container  'DOCUMENTSIZE'  documentsize.
    swc_refresh_object lv_object.
    swc_call_method    lv_object     'CREATE'        lv_container.
    swc_get_object_key lv_object     obj_roleb-objkey.



    obj_roleb-objtype = 'MESSAGE'. "Type of attach document
    obj_rolea-objtype = 'BKPF'.    "BO of SAP Document.

    CONCATENATE iv_bukrs "Company code
                iv_belnr "FI Document
                iv_gjahr "Fiscal year
                INTO obj_rolea-objkey.

    CALL FUNCTION 'BINARY_RELATION_CREATE_COMMIT'
      EXPORTING
        obj_rolea      = obj_rolea
        obj_roleb      = obj_roleb
        relationtype   = 'ATTA'
      IMPORTING
        binrel         = binrel
      TABLES
        binrel_attrib  = binrel_attrib
      EXCEPTIONS
        no_model       = 1
        internal_error = 2
        unknown        = 3
        OTHERS         = 4.
    IF sy-subrc = 0.
      ls_return-type = 'S'.
      ls_return-message = text-s01 && lv_filename && ' ' && IV_BELNR.
      APPEND ls_return TO et_return.
      RETURN.
    ELSE.
      ls_return-type = 'E'.
      ls_return-message = text-e04 && lv_filename.
      APPEND ls_return TO et_return.
      RETURN.
    ENDIF.
  ENDIF.

ENDFUNCTION.
