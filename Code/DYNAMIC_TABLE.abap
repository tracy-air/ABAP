  DATA:go_structdescr TYPE REF TO cl_abap_structdescr.
  DATA:gs_dfies TYPE dfies,
       gt_dfies TYPE ddfields.
  
  TYPES:BEGIN OF ty_faglflext.
          INCLUDE STRUCTURE faglflex_hsl.
  TYPES:ryear LIKE faglflext-ryear,
        rbukrs LIKE faglflext-rbukrs,
        racct LIKE faglflext-racct.
  TYPES:END OF ty_faglflext.
  DATA:lt_faglflext TYPE TABLE OF ty_faglflext,
       ls_faglflext TYPE ty_faglflext.

  TYPES:BEGIN OF ty_faglflext_collect.
          INCLUDE STRUCTURE faglflex_hsl.
  TYPES:ryear LIKE faglflext-ryear.
  TYPES:END OF ty_faglflext_collect.
  DATA:lt_faglflext_collect TYPE TABLE OF ty_faglflext_collect,
       ls_faglflext_collect TYPE ty_faglflext_collect.

  TYPES:BEGIN OF ty_hsl,
    hslxx_name TYPE string,
    hslxx_value TYPE hslxx12,
    END OF ty_hsl.
  DATA:lt_hsl TYPE TABLE OF ty_hsl,
       ls_hsl TYPE ty_hsl.
  
  DATA:lo_structdescr TYPE REF TO cl_abap_structdescr,
       ls_compdescr TYPE abap_compdescr,
       dy_table TYPE REF TO data.

  "行数据转换为列数据
  READ TABLE lt_faglflext_collect INTO ls_faglflext_collect INDEX 1.
  lo_structdescr ?= cl_abap_structdescr=>describe_by_data( ls_faglflext_collect ).
  LOOP AT lo_structdescr->components INTO ls_compdescr.
    ASSIGN COMPONENT ls_compdescr-name OF STRUCTURE ls_faglflext_collect TO <fs_field>.
    ls_hsl-hslxx_name = ls_compdescr-name.
    ls_hsl-hslxx_value = <fs_field>.
    IF ls_compdescr-name+0(3) EQ 'HSL'.
      APPEND ls_hsl TO lt_hsl.
    ENDIF.
    CLEAR:ls_hsl,ls_compdescr.
  ENDLOOP.
  
  "定义显示字段 其中gt_dfies表内的存的就是itab的字段
  go_structdescr ?= cl_abap_structdescr=>describe_by_data( itab ).
  CALL METHOD cl_salv_data_descr=>read_structdescr
    EXPORTING
      r_structdescr = go_structdescr
    RECEIVING
      t_dfies       = gt_dfies.
