*"添加附件到物料凭证

FUNCTION zpv_add_attach_to_mm_document.
*"----------------------------------------------------------------------
*"*"局部接口：
*"  IMPORTING
*"     REFERENCE(IV_FILENAME) TYPE  ZDOA_FILE_NAME
*"     REFERENCE(IV_FILE_CONTENT) TYPE  ZFILE_CONTENT
*"     REFERENCE(IV_MBLNR) TYPE  MBLNR
*"     REFERENCE(IV_MJAHR) TYPE  MJAHR
*"  TABLES
*"      ET_RETURN TYPE  BAPIRET1_TAB
*"----------------------------------------------------------------------
  INCLUDE:<cntn01>.

  DATA:ls_return TYPE LINE OF bapiret1_tab.
  DATA:lv_xstring TYPE xstring,
       lv_len TYPE i,
       lt_binary_tab TYPE solix OCCURS 0.
  DATA:documentsize TYPE i VALUE 0,
       lv_filename TYPE string,
       lv_extension TYPE string,
       filelength TYPE i,
       lv_object TYPE swc_object,
       obj_rolea TYPE borident,
       obj_roleb TYPE borident,
       binrel TYPE gbinrel,
       binrel_attrib TYPE STANDARD TABLE OF brelattr,
       lo_obj_head TYPE REF TO cl_bcs_objhead.

  CALL FUNCTION 'SSFC_BASE64_DECODE'
    EXPORTING
      b64data = iv_file_content
    IMPORTING
      bindata = lv_xstring.

  CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
    EXPORTING
      buffer        = lv_xstring
    IMPORTING
      output_length = lv_len
    TABLES
      binary_tab    = lt_binary_tab.

  SPLIT iv_filename AT '.' INTO lv_filename lv_extension.
  documentsize = lv_len.

* 将文件关联至物料凭证附件
  swc_container      lv_container.
* 将文件名添加到附件的文件名中
  lo_obj_head = cl_bcs_objhead=>create( ).
  lo_obj_head->set_filename( iv_filename ).
  swc_set_table lv_container  'DOCUMENTHEADER' lo_obj_head->mt_objhead.
  swc_create_object  lv_object     'MESSAGE'       ''.
  swc_set_element    lv_container  'NO_DIALOG'     'X'.
  swc_set_element    lv_container  'DOCUMENTTITLE' iv_filename.
  swc_set_table      lv_container  'Content_Hex'   lt_binary_tab.
  swc_set_element    lv_container  'DOCUMENTTYPE'  lv_extension.
  swc_set_element    lv_container  'DOCUMENTSIZE'  documentsize.
  swc_refresh_object lv_object.
  swc_call_method    lv_object     'CREATE'        lv_container.
  swc_get_object_key lv_object     obj_roleb-objkey.

  obj_roleb-objtype = 'MESSAGE'.
  obj_rolea-objtype = 'BUS2017'.

  CONCATENATE iv_mblnr iv_mjahr INTO obj_rolea-objkey.

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
    ls_return-message = text-s01 && iv_filename && ' ' && iv_mblnr.
    APPEND ls_return TO et_return.
    RETURN.
  ELSE.
    ls_return-type = 'E'.
    ls_return-message = text-e04 && iv_filename.
    APPEND ls_return TO et_return.
    RETURN.
  ENDIF.

ENDFUNCTION.
