from array import array
import math
import moderngl
from pyrr import Vector3, vector, vector3, matrix44
import moderngl_window as mglw




class App(mglw.WindowConfig):
    WIDTH, HEIGHT = 1280, 720
    # WIDTH, HEIGHT = 1920, 1080
    fullscreen = False;
    window_size = WIDTH, HEIGHT
    resource_dir = 'programs'
    lastX, lastY = WIDTH/2, HEIGHT/2
    first_mouse = True
    

    cam_pos = Vector3([0.0, 2.0, -4.0])
    cam_target = Vector3([0, 0, 0])
    yaw = 0
    pitch = 0
    flash_light = -1;


    keys = {}


    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.quad = mglw.geometry.quad_fs()
        self.program = self.load_program(vertex_shader='vertex.glsl', fragment_shader='fragment.glsl')
        self.u_scroll = 1.0

        ctx = moderngl.create_context()

        sdfBuffer = ctx.buffer(data=array("f",[1.0,1.0]))
        
        # keys

        # mouse // New code for cursor hiding. Still experimenting.

        self.wnd.cursor = True
        #self.wnd._mouse_pos = 300,300
        self.wnd.mouse_exclusivity = True

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
        self.program['u_flashlight'] = -1
        self.program['u_renderMode'] = 1
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
        self.program['u_time'] = time
        self.key_press()
        # self.texture1.use(location=1)
        # self.texture2.use(location=2)
        # self.texture3.use(location=3)
        # self.texture4.use(location=4)
        # self.texture5.use(location=5)
        # self.texture6.use(location=6)
        # self.texture7.use(location=7)
        self.quad.render(self.program)

    def clamp(self, n, min, max): 
        if n < min: 
            return min
        elif n > max: 
            return max
        else: 
            return n 
        
    def calc_camdir(self, dx, dy):
        self.yaw -= dx/150
        self.pitch = self.clamp(self.pitch - dy/150, -math.pi, math.pi)

        normal = Vector3([math.sin(self.yaw), self.pitch, math.cos(self.yaw)])

        self.cam_target = normal

        self.program['u_camTarget'] = normal

    def mouse_position_event(self, x, y, dx, dy):
        self.calc_camdir( dx, dy)
        
    
    def mouse_scroll_event(self, x_offset, y_offset):
        self.u_scroll = max(1.0, self.u_scroll + y_offset)
        print(self.u_scroll)
        self.program['u_scroll'] = self.u_scroll
    

    def key_event(self, key, action, modifiers):
        if key == self.wnd.keys.W:
            self.keys["W"] = action == self.wnd.keys.ACTION_PRESS
        if key == self.wnd.keys.A:
            self.keys["A"] = action == self.wnd.keys.ACTION_PRESS
        if key == self.wnd.keys.S:
            self.keys["S"] = action == self.wnd.keys.ACTION_PRESS
        if key == self.wnd.keys.D:
            self.keys["D"] = action == self.wnd.keys.ACTION_PRESS
        if key == self.wnd.keys.SPACE:
            self.keys["SPACE"] = action == self.wnd.keys.ACTION_PRESS

        self.keys["ctrl"] = modifiers.ctrl        
        self.keys["alt"] = modifiers.alt        

        if key == self.wnd.keys.F and action == self.wnd.keys.ACTION_PRESS:
            self.flash_light *= -1
        
        if key == self.wnd.keys.NUMBER_0 and action == self.wnd.keys.ACTION_PRESS:
            self.program['u_renderMode'] = 0
        if key == self.wnd.keys.NUMBER_1 and action == self.wnd.keys.ACTION_PRESS:
            self.program['u_renderMode'] = 1
        if key == self.wnd.keys.NUMBER_2 and action == self.wnd.keys.ACTION_PRESS:
            self.program['u_renderMode'] = 2
        if key == self.wnd.keys.NUMBER_3 and action == self.wnd.keys.ACTION_PRESS:
            self.program['u_renderMode'] = 3
        if key == self.wnd.keys.NUMBER_4 and action == self.wnd.keys.ACTION_PRESS:
            self.program['u_renderMode'] = 4
        
        self.keys["shift"] = self.wnd.modifiers.shift;

        self.program['u_flashlight'] = self.flash_light
        self.program['u_camPos'] = self.cam_pos
        

    def key_press(self):
        speed = 0.08
        if self.keys.get("ctrl"):
            speed = 0.3
        if self.keys.get("alt"):
            speed = 0.005
            
        if self.keys.get("W"):
            self.cam_pos += Vector3([speed*math.sin(self.yaw), 0.0, speed*math.cos(self.yaw)])
        if self.keys.get("A"):
            self.cam_pos += Vector3([speed*math.cos(self.yaw), 0.0, -speed*math.sin(self.yaw)])
        if self.keys.get("S"):
            self.cam_pos += Vector3([-speed*math.sin(self.yaw), 0.0, -speed*math.cos(self.yaw)])
        if self.keys.get("D"):
            self.cam_pos += Vector3([-speed*math.cos(self.yaw), 0.0, speed*math.sin(self.yaw)])
        if self.keys.get("SPACE"):
            self.cam_pos += Vector3([0.0, speed, 0.0])
        if self.keys.get("shift"):
            self.cam_pos += Vector3([0.0, -speed, 0.0])
        self.program['u_camPos'] = self.cam_pos      


if __name__ == '__main__':
    mglw.run_window_config(App)
