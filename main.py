from pyrr import Vector3, vector, vector3, matrix44
import moderngl_window as mglw

from camera import Camera

class App(mglw.WindowConfig):
    WIDTH, HEIGHT = 1280, 720
    window_size = WIDTH, HEIGHT
    resource_dir = 'programs'
    cam = Camera();
    lastX, lastY = WIDTH/2, HEIGHT/2
    first_mouse = True
    cam_pos = Vector3([0.0, 2.0, -4.0])
    keys = {}

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.quad = mglw.geometry.quad_fs()
        self.program = self.load_program(vertex_shader='vertex.glsl', fragment_shader='fragment.glsl')
        self.u_scroll = 3.0
        # keys

        # textures
        self.texture1 = self.load_texture_2d('../textures/test0.png')
        self.texture2 = self.load_texture_2d('../textures/hex.png')  # floor
        self.texture3 = self.load_texture_2d('../textures/white_marble1.png')  # walls
        self.texture4 = self.load_texture_2d('../textures/roof/texture3.jpg')  # roof
        self.texture5 = self.load_texture_2d('../textures/black_marble1.png')  # pedestal
        self.texture6 = self.load_texture_2d('../textures/green_marble1.png')  # sphere
        self.texture7 = self.load_texture_2d('../textures/roof/height3.png')  # roof bump
        # uniforms
        #self.program['u_scroll'] = self.u_scroll
        self.program['u_resolution'] = self.window_size
        # self.program['u_camPos'] = self.cam_pos
        # self.program['u_texture1'] = 1
        # self.program['u_texture2'] = 2
        # self.program['u_texture3'] = 3
        # self.program['u_texture4'] = 4
        # self.program['u_texture5'] = 5
        # self.program['u_texture6'] = 6
        # self.program['u_texture7'] = 7

    
        

    def render(self, time, frame_time):
        self.ctx.clear()
        # self.program['u_time'] = time
        self.key_press()
        # self.texture1.use(location=1)
        # self.texture2.use(location=2)
        # self.texture3.use(location=3)
        # self.texture4.use(location=4)
        # self.texture5.use(location=5)
        # self.texture6.use(location=6)
        # self.texture7.use(location=7)
        self.quad.render(self.program)

    def mouse_position_event(self, x, y, dx, dy):
        #self.program['u_mouse'] = (x, y)
        pass
    
    # def mouse_scroll_event(self, x_offset, y_offset):
    #     self.u_scroll = max(1.0, self.u_scroll + y_offset)
    #     self.program['u_scroll'] = self.u_scroll
    

    def key_event(self, key, action, modifiers):
        if key == self.wnd.keys.W.A:
            self.keys["W"] = action == self.wnd.keys.ACTION_PRESS
        if key == self.wnd.keys.A:
            self.keys["A"] = action == self.wnd.keys.ACTION_PRESS
        if key == self.wnd.keys.S:
            self.keys["S"] = action == self.wnd.keys.ACTION_PRESS
        if key == self.wnd.keys.D:
            self.keys["D"] = action == self.wnd.keys.ACTION_PRESS
        if key == self.wnd.keys.SPACE:
            self.keys["SPACE"] = action == self.wnd.keys.ACTION_PRESS
        #if modifiers == self.wnd.modifiers.ctrl:
        self.keys["shift"] = self.wnd.modifiers.shift;

        # self.program['u_camPos'] = self.cam_pos
        

    def key_press(self):
        speed = 0.05
        if self.keys.get("W"):
            self.cam_pos += Vector3([0.0, 0.0, speed])
        if self.keys.get("A"):
            self.cam_pos += Vector3([-speed, 0.0, 0.0])
        if self.keys.get("S"):
            self.cam_pos += Vector3([0.0, 0.0, -speed])
        if self.keys.get("D"):
            self.cam_pos += Vector3([speed, 0.0, 0.0])
        if self.keys.get("SPACE"):
            self.cam_pos += Vector3([0.0, speed, 0.0])
        if self.keys.get("shift"):
            self.cam_pos += Vector3([0.0, -speed, 0.0])
        # self.program['u_camPos'] = self.cam_pos

    # def assign_event_callbacks(self):
    #     return super().assign_event_callbacks()

    # def mouse_look_clb(self, window, xpos, ypos):
    #     if self.first_mouse:
    #         self.lastX = xpos
    #         self.lastY = ypos

    #     xOffset = xpos - self.lastX
    #     yOffset = self.lastY - ypos

    #     self.lastX = xpos
    #     self.lastY = ypos

    #     self.cam.process_mouse_movement(xOffset, yOffset)

    # def mouse_enter_clb(self, window, entered):
    #     self.first_mouse = not entered

            


if __name__ == '__main__':
    mglw.run_window_config(App)
