; docformat = 'rst'

;+
; GUI for manipulating a scene, including rotating, translating, and scaling a
; model within it, then drawing the scene to POV-Ray input files.
;
; To rotate the scene, click and drag using the left mouse button. To translate
; the scene, click and drag the middle mouse button. To scale the scene, click
; and drag the right mouse button (towards the center to shrink, away from the
; center to expand).
;
; The buttons in the toolbar write the POV-Ray files and spawn POV-Ray to run on
; the exported files, respectively. Changing the size of the display via the
; droplist or by dragging the corner of the window changes the size of the
; output image.
;
; .. image:: mg_xpovray.png
;
; :Categories:
;    object graphics, widget utility
;
; :Todo:
;    * add run on subset feature (rubberband box)
;    * draw line to center when zooming
;
; :Properties:
;    dimensions
;       size of graphics display
;-


;+
; Procedural wrapper for event handler, see ::handleEvent for the real event
; handler.
;
; :Private:
;
; :Params:
;    event : in, required, type=structure
;       all events generated by the application
;-
pro mg_xpovray_event, event
  compile_opt strictarr

  widget_control, event.top, get_uvalue=pov
  pov->handleEvent, event
end


;+
; Procedural wrapper for the cleanup. Destroys the application object.
;
; :Private:
;-
pro mg_xpovray_cleanup, tlb
  compile_opt strictarr

  widget_control, tlb, get_uvalue=pov
  obj_destroy, pov
end


;+
; Refresh graphics.
;
; :Private:
;-
pro mgwidpovray::refresh
  compile_opt strictarr

  self.win->draw, self.view
end


;+
; Resize the draw widget.
;
; :Private:
;
; :Params:
;    dims : in, required, type=lonarr(2)
;       new dimensions of the draw widget
;-
pro mgwidpovray::resizeDraw, dims
  compile_opt strictarr

  self.dims = dims

  draw = widget_info(self.tlb, find_by_uname='draw')
  widget_control, draw, xsize=dims[0], ysize=dims[1]

  self.rotateTrackball->reset, self.dims / 2, max(self.dims / 2)
  self.translateTrackball->reset, self.dims / 2, max(self.dims / 2)
end


;+
; Main event handler for the application.
;
; :Private:
;
; :Params:
;    event : in, required, type=structure
;       all events generated by the application
;-
pro mgwidpovray::handleEvent, event
  compile_opt strictarr

  uname = widget_info(event.id, /uname)
  case uname of
    'tlb': begin   ; resize event
        controls = widget_info(self.tlb, find_by_uname='controls')

        tlbG = widget_info(self.tlb, /geometry)
        controlsG = widget_info(controls, /geometry)

        dims = [event.x - 2 * tlbG.xpad, $
                event.y - 2 * tlbG.ypad - tlbG.space - controlsG.scr_ysize]

        sizesDroplist = widget_info(self.tlb, find_by_uname='sizes')
        widget_control, sizesDroplist, get_value=sizes
        sizes[0] = strjoin(strtrim(long(dims), 2), ' x ')
        widget_control, sizesDroplist, set_value=sizes, set_droplist_select=0

        self->resizeDraw, dims
        self->refresh
      end
    'export': begin
        widget_control, /hourglass
        self.basename = dialog_pickfile(title='Select output basename', $
                                        dialog_parent=self.tlb, $
                                        path=self.dirname)
        if (self.basename eq '') then break

        self.dirname = file_dirname(self.basename)
        if (~file_test(self.dirname)) then file_mkdir, self.dirname

        pov = obj_new('MGgrPovray', file_prefix=self.basename, $
                      dimensions=self.dims)
        pov->draw, self.view
        obj_destroy, pov
      end
    'run': begin
        widget_control, /hourglass
        if (self.basename eq '') then break

        window, /free, title=self.basename, xsize=self.dims[0], ysize=self.dims[1]
        tv, mg_povray(self.basename), true=1
      end
    'sizes': begin
        if (event.index eq 0L) then begin
          widget_control, event.id, get_value=sizes
          dims = strsplit(sizes[0], /extract)
          dims = long(dims[[0, 2]])

          self->resizeDraw, dims
          self->refresh
        endif else begin
          self->resizeDraw, reform((*self.sizes)[*, event.index - 1])
          self->refresh
        endelse
      end
    'draw': begin
        rotateUpdate = self.rotateTrackball->update(event, mouse=1, $
                                                    transform=rotationTransform)
        if (rotateUpdate) then begin
          self.model->getProperty, transform=transform
          self.model->setProperty, transform=transform # rotationTransform
          self->refresh
        endif

        translateUpdate = self.translateTrackball->update(event, mouse=2, $
                                                          /translate, $
                                                          transform=translationTransform)
        if (translateUpdate) then begin
          self.model->getProperty, transform=transform
          self.model->setProperty, transform=transform # translationTransform
          self->refresh
        endif


        if ((event.press and 4B) eq 4B) then begin
          self.scaling = 1B
          self.scalingDistance = sqrt(total((self.dims / 2 - [event.x, event.y])^2))

          self.model->getProperty, transform=transform
          self.scalingTransform = transform
        endif

        if ((event.release and 4B) eq 4B) then self.scaling = 0B

        if (self.scaling) then begin
          scalingDistance = sqrt(total((self.dims / 2 - [event.x, event.y])^2))
          s =  scalingDistance / self.scalingDistance

          self.model->setProperty, transform=self.scalingTransform
          self.model->scale, s, s, s

          self->refresh
        endif
      end
    else:
  endcase
end


;+
; Create the widget interface.
;
; :Private:
;-
pro mgwidpovray::createWidgets
  compile_opt strictarr

  self.tlb = widget_base(title='POV-Ray scene viewer/exporter', $
                         uname='tlb', uvalue=self, $
                         /column, xpad=0, ypad=0, space=0, $
                         /tlb_size_events)

  controls = widget_base(self.tlb, uname='controls', $
                         /row, /toolbar, xpad=0, ypad=0, space=0)

  exportButton = widget_button(controls, value='Export to POV-Ray', uname='export')
  runButton = widget_button(controls, value='Run POV-Ray', uname='run')

  sizes = [strjoin(strtrim(self.dims, 2), ' x '), $
           strjoin(strtrim(*self.sizes, 2), ' x ')]
  sizesDroplist = widget_droplist(controls, value=sizes, uname='sizes')

  draw = widget_draw(self.tlb, uname='draw', $
                     xsize=self.dims[0], ysize=self.dims[1], $
                     graphics_level=2, $
                     /button_events, /motion_events)
end


;+
; Draw the widgets on the screen.
;
; :Private:
;-
pro mgwidpovray::realizeWidgets
  compile_opt strictarr

  widget_control, self.tlb, /realize

  draw = widget_info(self.tlb, find_by_uname='draw')
  widget_control, draw, get_value=win
  self.win = win
  self.win->setCurrentCursor, 'ORIGINAL'
end


;+
; Start the event handling loop.
;
; :Private:
;-
pro mgwidpovray::startXManager
  compile_opt strictarr

  xmanager, 'xpovray', self.tlb, /no_block, $
            event_handler='mg_xpovray_event', $
            cleanup='mg_xpovray_cleanup'
end


;+
; Destroys the widget program and resources (but not the object graphics
; hierarchy, that is owned by the caller).
;
; :Private:
;-
pro mgwidpovray::cleanup
  compile_opt strictarr

  ptr_free, self.sizes
  obj_destroy, self.rotateTrackball
  widget_control, self.tlb, /destroy
end


;+
; Creates the application object.
;
; :Private:
;
; :Returns:
;    1 for success, 0 for failure
;
; :Params:
;    view : in, required, type=object
;       view to display
;    model : in, required, type=object
;       model to rotate, translate, or scale
;
; :Keywords:
;    dimensions : in, optional, type=lonarr(2), default="[500, 500]"
;       size of graphics display
;-
function mgwidpovray::init, view, model, dimensions=dimensions
  compile_opt strictarr

  self.view = view
  self.model = model

  self.dims = n_elements(dimensions) eq 0L ? [500, 500] : dimensions
  self.sizes = ptr_new([[1920, 1200], [800, 800], [640, 480], [320, 240]])

  self->createWidgets
  self->realizeWidgets
  self->startXManager
  self->refresh

  self.rotateTrackball = obj_new('Trackball', $
                                 self.dims / 2, max(self.dims / 2), $
                                 mouse=1)
  self.translateTrackball = obj_new('Trackball', $
                                    self.dims / 2, max(self.dims / 2), $
                                    mouse=2)

  return, 1
end


;+
; Define instance variables.
;
; :Private:
;-
pro mgwidpovray__define
  compile_opt strictarr

  define = { MGwidPOVRay, $
             tlb: 0L, $
             win: obj_new(), $
             view: obj_new(), $
             model: obj_new(), $
             rotateTrackball: obj_new(), $
             translateTrackball: obj_new(), $
             scaling: 0B, $
             scalingTransform: fltarr(4, 4), $
             scalingDistance: 0.0, $
             dims: lonarr(2), $
             sizes: ptr_new(), $
             basename: '', $
             dirname: '' $
           }
end


;+
; Launch the POV-Ray application.
;
; :Params:
;    view : in, required, type=IDLgrView
;       view to display
;
; :Keywords:
;    model : in, optional, type=IDLgrModel reference
;       model to rotate, translate, and scale; if not specified, gets first
;       model in the hierarchy
;    dimensions : in, optional, type=lonarr(2)
;       size of graphics display
;-
pro mg_xpovray, view, model=model, dimensions=dimensions
  compile_opt strictarr
  on_error, 2

  if (~obj_valid(view) || ~obj_isa(view, 'IDLgrView')) then begin
    message, 'invalid view'
  endif

  _model = (obj_valid(model) && obj_isa(model, 'IDLgrModel')) $
             ? model $
             : view->get(position=0)

  xpovray = obj_new('MGwidPOVRay', view, _model, dimensions=dimensions)
end


; main-level example program of using the `MG_XPOVRAY` routine

view = obj_new('IDLgrView', name='view', color=[200, 200, 255])

model = obj_new('IDLgrModel', name='model')
view->add, model

cowFilename = filepath('cow10.sav', subdir=['examples', 'data'])
restore, cowFilename
colors = randomu(seed, n_elements(x))
vertcolors = rebin(reform(255 * round(colors), 1, n_elements(x)), 3, n_elements(x))

cow = obj_new('IDLgrPolygon', x, y, z, polygons=polylist, $
              color=[150, 100, 20], shading=1, $
              ;vert_colors=vertcolors, clip_planes=[0, 0, 1, 0], $
              shininess=25.0, ambient=[150, 100, 20], diffuse=[150, 100, 20])
model->add, cow

xmin = min(x, max=xmax)
xrange = xmax - xmin
ymin = min(y, max=ymax)
yrange = ymax - ymin
zmin = min(z, max=zmax)
zrange = zmax - zmin

plane = obj_new('IDLgrPolygon', $
                [xmin, xmin, xmax, xmax] + [-1., -1., 1., 1.] * 5. * xrange, $
                fltarr(4) + ymin, $
                [zmin, zmax, zmax, zmin] + [-1., 1., 1., -1.] * 5. * zrange, $
                color=[25, 100, 50], style=2)
model->add, plane

model->rotate, [0, 1, 0], -45
model->rotate, [1, 0, 0], 30

light = obj_new('IDLgrLight', type=2, location=[0, 5, 5], intensity=2.0)
model->add, light
alight = obj_new('IDLgrLight', type=0, intensity=2.0)
model->add, alight

mg_xpovray, view, dimensions=[600, 600]

end
