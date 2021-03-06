cimport cython
from libc.math cimport floor


cdef class Seek_Bar(UI_element):
    '''Seek bar that visualizes seek handles, trim marks and playback buttons

    Hover modes (descending priority):
        1   Seek handle is being hovered
        2   Right trim mark handle is being hovered
        3   Left trim mark handle is being hovered
        4   Seek bar is being hovered
        0   Seek bar is not being hovered
    '''

    cdef double min_ts, mid_ts, max_ts
    cdef Vec2 point_click_seek_loc
    cdef readonly int hovering
    cdef FitBox bar, seek_handle, trim_left_handle, trim_right_handle
    cdef readonly bint seeking, trimming_left, trimming_right
    cdef Synced_Value trim_left, trim_right, current, playback_speed
    cdef object seeking_cb
    cdef Timeline_Menu handle_start_reference
    cdef Icon backwards, play, forwards

    def __cinit__(self, object ctx, double min_ts, double max_ts, object seeking_cb,
                  Timeline_Menu handle_start_reference, *args, **kwargs):
        self.uid = id(self)
        self.trim_left = Synced_Value('trim_left_ts', ctx, trigger_overlay_only=True)
        self.trim_right = Synced_Value('trim_right_ts', ctx, trigger_overlay_only=True)
        self.current = Synced_Value('current_ts', ctx, trigger_overlay_only=True)
        self.playback_speed = Synced_Value('playback_speed', ctx, trigger_overlay_only=True)
        self.seeking_cb = seeking_cb
        self.min_ts = min_ts
        self.max_ts = max_ts
        self.mid_ts = (min_ts + max_ts) / 2
        self.hovering = 0
        self.seeking = False
        self.trimming_left = False
        self.trimming_right = False
        self.handle_start_reference = handle_start_reference

        self.point_click_seek_loc = Vec2(0., 0.)
        self.outline = FitBox(Vec2(0., -50.), Vec2(0., 0.))
        self.bar = FitBox(Vec2(130., 21.), Vec2(-30., 3.))
        self.seek_handle = FitBox(Vec2(0., 0.), Vec2(0., 0.))
        self.trim_left_handle = FitBox(Vec2(0., 0.), Vec2(0., 0.))
        self.trim_right_handle = FitBox(Vec2(0., 0.), Vec2(0., 0.))

        play_icon = chr(0xE037)
        pause_icon = chr(0xe034)
        step_fwd_icon = chr(0xe044)
        step_bwd_icon = chr(0xe045)
        incr_pbs_icon = chr(0xE01F)  # pbs: playback speed
        decr_pbs_icon = chr(0xE020)

        def set_play(_):
            if ctx.play:
                self.backwards.label = step_bwd_icon
                self.forwards.label = step_fwd_icon
                self.play.label = play_icon
                ctx.play = False
            else:
                self.backwards.label = decr_pbs_icon
                self.forwards.label = incr_pbs_icon
                self.play.label = pause_icon
                ctx.play = True

        self.backwards = Icon('backwards', ctx, label_font='pupil_icons',
                              label=step_bwd_icon,
                              getter=lambda: True,
                              hotkey=263)  # 263 = glfw.GLFW_KEY_LEFT
        self.forwards = Icon('forwards', ctx, label_font='pupil_icons',
                             label=step_fwd_icon,
                             hotkey=262,  # 262 = glfw.GLFW_KEY_RIGHT
                             getter=lambda: True)

        self.play = Icon('play', ctx, label_font='pupil_icons',
                         label=play_icon,
                         hotkey=32, # 32 = glfw.GLFW_KEY_SPACE
                         setter=set_play,
                         getter=lambda: True)

        self.backwards.outline = FitBox(Vec2(5, 0),Vec2(40, 40))
        self.play.outline = FitBox(Vec2(40, 0),Vec2(40, 40))
        self.forwards.outline = FitBox(Vec2(75, 0),Vec2(40, 40))

    def __init__(self, *args, **kwargs):
        pass

    cpdef sync(self):
        self.trim_left.sync()
        self.trim_right.sync()
        self.current.sync()
        self.playback_speed.sync()
        self.backwards.sync()
        self.play.sync()
        self.forwards.sync()

    cpdef draw(self,FitBox parent,bint nested=True, bint parent_read_only = False):
        self.outline.compute(parent)
        self.outline.sketch(RGBA(0., 0., 0., 0.3))
        self.bar.compute(self.outline)
        self.bar.sketch(RGBA(1., 1., 1., 0.4))

    cpdef draw_overlay(self,FitBox parent,bint nested=True, bint parent_read_only = False):

        self.backwards.draw(self.outline, nested=True, parent_read_only=False)
        self.play.draw(self.outline, nested=True, parent_read_only=False)
        self.forwards.draw(self.outline, nested=True, parent_read_only=False)

        cdef FitBox handle = FitBox(Vec2(0., 0.), Vec2(0., 0.))
        cdef double current_val = self.current.value
        cdef double trim_left_val = self.trim_left.value
        cdef double trim_right_val = self.trim_right.value
        cdef double seek_x = clampmap(current_val, self.min_ts, self.max_ts, 0, self.bar.size.x)
        cdef double top_ext = self.handle_start_reference.element_space.org.y
        cdef double bot_ext = self.bar.org.y + self.bar.size.y + 20 * ui_scale
        cdef double selection_height = 5 * self.bar.size.y

        cdef double trim_l_x = clampmap(trim_left_val, self.min_ts, self.max_ts, 0, self.bar.size.x)
        handle.org.x = int(self.bar.org.x + trim_l_x - selection_height)
        handle.org.y = self.bar.org.y + self.bar.size.y / 2 - selection_height / 2
        handle.size.x = selection_height
        handle.size.y = selection_height
        self.trim_left_handle = draw_trim_handle(handle, 0.25, RGBA(*seekbar_trim_color_hover if self.hovering == 3 else seekbar_trim_color))

        cdef double trim_r_x = clampmap(trim_right_val, self.min_ts, self.max_ts, 0, self.bar.size.x)
        handle.org.x = int(self.bar.org.x + trim_r_x)
        handle.org.y = self.bar.org.y + self.bar.size.y / 2 - selection_height / 2
        self.trim_right_handle = draw_trim_handle(handle, 0.75, RGBA(*seekbar_trim_color_hover if self.hovering == 2 else seekbar_trim_color))

        # draw region between trim marks
        handle.size.x = handle.org.x - int(self.bar.org.x + trim_l_x)
        handle.org.x = int(self.bar.org.x + trim_l_x)
        handle.size.y = self.bar.size.y
        rect(handle.org, handle.size, RGBA(*seekbar_trim_color))

        handle.org.y += selection_height - handle.size.y
        rect(handle.org, handle.size, RGBA(*seekbar_trim_color))

        handle.org = Vec2(int(self.bar.org.x + seek_x - self.bar.size.y / 4), top_ext)
        handle.size = Vec2(self.bar.size.y / 2, bot_ext - top_ext)
        self.seek_handle = draw_seek_handle(handle, RGBA(*seekbar_seek_color_hover if self.hovering == 1 else seekbar_seek_color))

        if self.hovering == 4:
            utils.draw_points([self.point_click_seek_loc],
                              size=4*self.bar.size.y,
                              color=RGBA(*seekbar_seek_color_hover))

        # debug draggable areas
        # rect(self.seek_handle.org, self.seek_handle.size, RGBA(1., 0., 0., 0.2))
        # rect(self.trim_left_handle.org, self.trim_left_handle.size, RGBA(1., 0., 0., 0.2))
        # rect(self.trim_right_handle.org, self.trim_right_handle.size, RGBA(1., 0., 0., 0.2))

        cdef basestring speed_str = '{}x'.format(self.playback_speed.value)
        cdef basestring current_ts_str = self.format_ts(current_val)
        cdef basestring trim_left_str = self.format_ts(trim_left_val)
        cdef basestring trim_right_str = self.format_ts(trim_right_val)

        cdef double trim_num_offset = 3. * ui_scale
        cdef double time_y = self.bar.org.y - selection_height / 2 + 2*ui_scale
        cdef double nums_y = self.play.button.org.y + self.play.button.size.y - seekbar_number_size * ui_scale / 3
        # if self.hovering or self.seeking or self.trimming_left or self.trimming_right:
        glfont.push_state()
        glfont.set_font('opensans')
        glfont.set_size(seekbar_number_size * ui_scale)

        # draw actual text
        glfont.set_blur(.1)
        glfont.set_color_float((1., 1., 1., 1.))

        if current_val < self.mid_ts:
            glfont.set_align(fs.FONS_ALIGN_BOTTOM | fs.FONS_ALIGN_LEFT)
            glfont.draw_text(self.bar.org.x + seek_x + 5*ui_scale, time_y, current_ts_str)
        else:
            glfont.set_align(fs.FONS_ALIGN_BOTTOM | fs.FONS_ALIGN_RIGHT)
            glfont.draw_text(self.bar.org.x + seek_x - 5*ui_scale, time_y, current_ts_str)

        glfont.set_align(fs.FONS_ALIGN_TOP | fs.FONS_ALIGN_CENTER)
        # glfont.draw_text(self.seek_handle.org.x+self.seek_handle.size.x/2,
        #                  self.seek_handle.org.y+self.seek_handle.size.y + 3. * ui_scale,
        #                  speed_str)
        glfont.draw_text(self.play.button.center[0], nums_y, speed_str)

        glfont.set_align(fs.FONS_ALIGN_TOP | fs.FONS_ALIGN_RIGHT)
        glfont.draw_text(self.trim_left_handle.center[0] - trim_num_offset, nums_y, trim_left_str)

        glfont.set_align(fs.FONS_ALIGN_TOP | fs.FONS_ALIGN_LEFT)
        glfont.draw_text(self.trim_right_handle.center[0] + trim_num_offset, nums_y, trim_right_str)

        glfont.pop_state()

    @cython.cdivision(True)
    cdef format_ts(self, double ts):
        cdef double minutes, seconds
        ts -= self.min_ts
        minutes = floor(ts / 60)
        seconds = ts - (minutes * 60.)
        return '{:02.0f}:{:06.3f}'.format(minutes, seconds)

    cpdef handle_input(self,Input new_input, bint visible, bint parent_read_only = False):
        self.backwards.handle_input(new_input, True, parent_read_only=False)
        self.play.handle_input(new_input, True, parent_read_only=False)
        self.forwards.handle_input(new_input, True, parent_read_only=False)

        global should_redraw_overlay
        if self.seeking and new_input.dm:
            val = clampmap(new_input.m.x-self.bar.org.x, 0, self.bar.size.x,
                           self.min_ts, self.max_ts)
            self.current.value = val
            should_redraw_overlay = True
        elif self.trimming_right and new_input.dm:
            val = clampmap(new_input.m.x-self.bar.org.x, 0, self.bar.size.x,
                           self.min_ts, self.max_ts)
            self.trim_right.value = val
            should_redraw_overlay = True
        elif self.trimming_left and new_input.dm:
            val = clampmap(new_input.m.x-self.bar.org.x, 0, self.bar.size.x,
                           self.min_ts, self.max_ts)
            self.trim_left.value = val
            should_redraw_overlay = True

        if self.seek_handle.mouse_over(new_input.m) or self.seeking:
            should_redraw_overlay = should_redraw_overlay or self.hovering != 1
            self.hovering = 1
        elif self.trim_right_handle.mouse_over(new_input.m) or self.trimming_right:
            should_redraw_overlay = should_redraw_overlay or self.hovering != 2
            self.hovering = 2
        elif self.trim_left_handle.mouse_over(new_input.m) or self.trimming_left:
            should_redraw_overlay = should_redraw_overlay or self.hovering != 3
            self.hovering = 3
        elif self.bar.mouse_over_margin(new_input.m, Vec2(0, 10 * ui_scale)):
            self.point_click_seek_loc = Vec2(new_input.m.x, self.bar.center[1])
            should_redraw_overlay = should_redraw_overlay or self.hovering != 4 or new_input.dm.x != 0
            self.hovering = 4
        else:
            should_redraw_overlay = should_redraw_overlay or self.hovering != 0
            self.hovering = 0


        for b in new_input.buttons[:]: # list copy for remove to work
            if b[1] == 1:
                if self.hovering == 4:
                    val = clampmap(new_input.m.x-self.bar.org.x, 0,
                                   self.bar.size.x, self.min_ts, self.max_ts)
                    self.current.value = val
                    self.hovering = 1
                    should_redraw_overlay = True

                if self.hovering == 1:
                    new_input.buttons.remove(b)
                    self.seeking = True
                    should_redraw_overlay = True
                    self.seeking_cb(True)
                elif self.hovering == 2:
                    new_input.buttons.remove(b)
                    self.trimming_right = True
                    should_redraw_overlay = True
                elif self.hovering == 3:
                    new_input.buttons.remove(b)
                    self.trimming_left = True
                    should_redraw_overlay = True

            if self.seeking and b[1] == 0:
                self.seeking = False
                should_redraw_overlay = True
                self.seeking_cb(False)
            elif self.trimming_right and b[1] == 0:
                self.trimming_right = False
                should_redraw_overlay = True
            elif self.trimming_left and b[1] == 0:
                self.trimming_left = False
                should_redraw_overlay = True
