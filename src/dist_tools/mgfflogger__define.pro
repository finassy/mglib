; docformat = 'rst'

;+
; Logger object to control logging.
;
; :Properties:
;    name : type=string
;       name of the logger
;    parent : private
;       parent logger
;    level : type=long
;       current level of logging: 0 (none), 1 (critial), 2 (error),
;       3 (warning), 4 (info), or 5 (debug); can be set to an array of levels
;       which will be cascaded up to the parents of the logger with the
;       logger taking the last level and passing the previous ones up to its
;       parent; only messages with levels lower or equal to than the logger
;       level will be logged
;    time_format : type=string
;       Fortran style format code to specify the format of the time in the
;       `FORMAT` property; the default value formats the time/date like
;       "2003-07-08 16:49:45.891"
;    format : type=string
;       format string for messages, default value for format is::
;
;         '%(time)s %(levelname)s: %(routine)s: %(message)s'
;
;       where the possible names to include are: "time", "levelname",
;       "routine", "stacktrace", "name", and "message".
;
;       Note that the time argument will first be formatted using the
;       `TIME_FORMAT` specification
;    filename : type=string
;       filename to send append output to; set to empty string to send output
;       to `stderr`
;    clobber : type=boolean
;       set, along with filename, to clobber pre-existing file
;    output : type=strarr
;        output sent to the logger already
;    _extra : type=keywords
;       any keyword accepted by `MGffLogger::setProperty`
;-


;+
; Get the minimum level value of this logger and all its parents.
;
; :Private:
;
; :Returns:
;    long
;-
function mgfflogger::_getLevel
  compile_opt strictarr

  return, obj_valid(self.parent) $
            ? (self.parent->_getLevel() < self.level) $
            : self.level
end


;+
; Finds the name of an object, even if it does not have a `NAME` property.
; Returns the empty string if the object does not have a `NAME` property.
;
; :Private:
;
; :Returns:
;    string
;
; :Params:
;    obj : in, required, type=object
;       object to find name of
;-
function mgfflogger::_askName, obj
  compile_opt strictarr

  catch, error
  if (error ne 0L) then begin
    catch, /cancel
    return, ''
  endif

  obj->getProperty, name=name
  return, name
end


;+
; Returns an immediate child of a container by name.
;
; :Private:
;
; :Returns:
;    object
;
; :Params:
;    name : in, required, type=string
;       name of immediate child
;    container : in, required, type=object
;       container to search children of
;-
function mgfflogger::_getChildByName, name, container
  compile_opt strictarr

  for i = 0L, container.children->count() - 1L do begin
    child = container.children->get(position=i)
    childName = self->_askName(child)
    if (childName eq name) then return, child
  endfor

  return, obj_new()
end


;+
; Traverses a hierarchy of named objects using a path of names delimited with
; /'s.
;
; :Returns:
;    object
;
; :Params:
;    name : in, required, type=string
;       path of names to the desired object; names are delimited with /'s
;-
function mgfflogger::getByName, name
  compile_opt strictarr

  tokens = strsplit(name, '/', /extract, count=ntokens)
  child = self
  for depth = 0L, ntokens - 1L do begin
    newChild = self->_getChildByName(tokens[depth], child)
    if (~obj_valid(newChild)) then begin
      newChild = obj_new('MGffLogger', name=tokens[depth], parent=child)
      child.children->add, newChild
    endif
    child = newChild
  endfor

  return, child
end


;+
; Set properties.
;-
pro mgfflogger::getProperty, level=level, $
                             format=format, time_format=time_format, $
                             name=name, $
                             filename=filename, $
                             output=output
  compile_opt strictarr

  if (arg_present(level)) then level = self.level
  if (arg_present(format)) then format = self.format
  if (arg_present(time_format)) then time_format = self.time_format
  if (arg_present(name)) then name = self.name
  if (arg_present(filename)) then filename = self.filename
  if (arg_present(output)) then begin
    if (self.filename ne '') then begin
      output = strarr(file_lines(self.filename))
      openr, lun, self.filename, /get_lun
      readf, lun, output
    endif
  endif
end


;+
; Get properties.
;-
pro mgfflogger::setProperty, level=level, $
                             format=format, time_format=time_format, $
                             filename=filename, clobber=clobber
  compile_opt strictarr

  case n_elements(level) of
    0:
    1: self.level = level
    else: begin
        self.level = level[n_elements(level) - 1L]
        if (obj_valid(self.parent)) then begin
          self.parent->setProperty, level=level[0:n_elements(level) - 2L]
        endif
      end
  endcase

  if (n_elements(format) gt 0L) then self.format = format
  if (n_elements(time_format) gt 0L) then self.time_format = time_format
  if (n_elements(filename) gt 0L) then self.filename = filename
  if (keyword_set(clobber) && n_elements(filename) gt 0L) then begin
    if (file_test(filename)) then file_delete, filename
  endif
end


;+
; Insert the stack trace for the last error message into the log. Since stack
; traces are from run-time crashes they are considered to be at the CRITICAL
; level.
;
; :Keywords:
;    back_levels : in, optional, private, type=boolean
;       number of levels to go back in the stack trace beyond the normal ones;
;       should be set to 1 if calling this routine from `MG_LOG` for example
;-
pro mgfflogger::insertLastError, back_levels=back_levels
  compile_opt strictarr

  _back_levels = n_elements(back_levels) eq 0L ? 0 : back_levels

  help, /last_message, output=helpOutput
  if (n_elements(helpOutput) eq 1L && helpOutput[0] eq '') then return

  self->print, 'Stack trace for error', level=1, back_levels=_back_levels + 1L

  if (self.filename eq '') then begin
    lun = -2L
  endif else begin
    if (file_test(self.filename)) then begin
      openu, lun, self.filename, /get_lun, /append
    endif else begin
      openw, lun, self.filename, /get_lun
    endelse
  endelse

  printf, lun, transpose(helpOutput)

  if (lun ge 0L) then free_lun, lun
end


;+
; Log message to given level.
;
; :Params:
;    msg : in, required, type=string
;       message to print
;
; :Keywords:
;    level : in, optional, type=long
;       level of message
;    back_levels : in, optional, private, type=boolean
;       number of levels to go back in the stack trace beyond the normal ones;
;       should be set to 1 if calling this routine from `MG_LOG` for example
;-
pro mgfflogger::print, msg, level=level, back_levels=back_levels
  compile_opt strictarr

  _back_levels = n_elements(back_levels) eq 0L ? 0 : back_levels

  if (self.filename eq '') then begin
    lun = -2L
  endif else begin
    if (file_test(self.filename)) then begin
      openu, lun, self.filename, /get_lun, /append
    endif else begin
      openw, lun, self.filename, /get_lun
    endelse
  endelse

  if (level le self->_getLevel()) then begin
    stack = scope_traceback(/structure, /system)
    vars = { time: string(systime(/julian), format='(' + self.time_format + ')'), $
             levelname: strupcase(self.levelNames[level - 1L]), $
             routine: stack[n_elements(stack) - 2L - _back_levels].routine, $
             stacktrace: strjoin(stack[0:n_elements(stack) - 2L - _back_levels].routine, '->'), $
             name: self.name, $
             message: msg $
           }
    s = mg_subs(self.format, vars)
    printf, lun, s
  endif

  if (lun ge 0L) then free_lun, lun
end


;+
; Free resources.
;-
pro mgfflogger::cleanup
  compile_opt strictarr

  if (obj_valid(self.parent)) then begin
    (self.parent).children->remove, self
  endif

  obj_destroy, self.children
end


;+
; Create logger object.
;
; :Returns:
;    1 for success, 0 for failure
;-
function mgfflogger::init, parent=parent, name=name, _extra=e
  compile_opt strictarr

  self.parent = n_elements(parent) eq 0L ? obj_new() : parent
  self.name = n_elements(name) eq 0L ? '' : name
  self.children = obj_new('IDL_Container')

  self.time_format = 'C(CYI4.4, "-", CMOI2.2, "-", CDI2.2, " ", CHI2.2, ":", CMI2.2, ":", CSF06.3)'
  self.format = '%(time)s %(levelname)s: %(routine)s: %(message)s'

  self.level = 0L
  self.levelNames = ['Critical', 'Error', 'Warning',  'Informational', 'Debug']

  self->setProperty, _extra=e

  return, 1
end


;+
; Define instance variables.
;
; :Fields:
;    parent
;       parent `MGffLoffer` object
;    name
;       name of the loffer
;    children
;       `IDL_Container` of children loggers
;    level
;       current level of logging: 0=none, 1=critical, 2=error, 3=warning,
;       4=informational, or 5=debug; only messages with a level lower or equal
;       to this this value will be logged
;    levelNames
;       names for the different levels
;    filename
;       filename to send output to
;    time_format
;       Fortran format codes for calendar output
;    format
;       format code to send output to
;-
pro mgfflogger__define
  compile_opt strictarr

  define = { MGffLogger, $
             parent: obj_new(), $
             name: '', $
             children: obj_new(), $
             level: 0L, $
             levelNames: strarr(5), $
             filename: '', $
             time_format: '', $
             format: '' $
           }
end
