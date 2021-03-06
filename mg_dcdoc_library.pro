; docformat = 'rst'

;+
; Make the Doc Center API documentation for the library.
;-
pro mg_dcdoc_library
  compile_opt strictarr

  root = mg_src_root()   ; location of this file

  idldoc, root=filepath('src', root=root), $
          output=filepath('api-dcdocs', root=root), $
          overview=filepath('overview.txt', root=root), $
          title='mglib', $
          subtitle='Personal IDL library for M. Galloy', $
          index_level=1, format_style='rst', $
          /doc_center
end
