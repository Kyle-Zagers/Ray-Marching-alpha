#version 330 core
#include hg_sdf.glsl

layout (location = 0) out vec4 fragColor;

precision mediump float;

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_scroll;
uniform vec3 u_camPos;
uniform vec3 u_camTarget;
uniform int u_flashlight;
uniform int u_renderMode;

const float MAX_STEPS = 500.0;
const float MIN_DIST_TO_SDF = 0.000001;
const float MAX_DIST_TO_TRAVEL = 100.0;
const float EPSILON = 0.001;
const float LOD_MULTIPLIER = 60;




struct Light {
  float size;
  vec3 pos;
  vec3 col;
  vec3 dir;
  float focus;  
  float spread;
};


vec2 calcSDF(vec3 pos) {
    float matID = 0.0; //temporary default


    float plane = fPlane(pos, vec3(0.0, 1.0, 0.0), 1.0);
    float box = fBox(pos-vec3(-4, -0.5, -3), vec3(0.5));
    float box2 = fBox(pos-vec3(1.5, -0.5, -3), vec3(0.5));
    float longBox = fBox(pos-vec3(0, -1, -2), vec3(30, 0.5, 0.5));
    float blob = fBlob(pos-vec3(0, 1, 0));

    //float mengerOld = max(fBox(pos-vec3(0, 2, -10), vec3(2.0)), -getInnerMenger(pos-vec3(0, 2, -10), 2.0));
    float menger = fMenger((pos-vec3(0, 15, -25)), 8, 15.0);
    vec4 temp;
    float mandel = mandelbulb(pos-vec3(5, 1, 0), temp);

    float dist = min(plane, box);
    dist = min(longBox, dist);
    dist = min(blob, dist);
    dist = min(box2, dist);
    //dist = min(mengerOld, dist);
    dist = min(menger, dist);
    dist = min(mandel, dist);

    return vec2(dist, matID);
}


float calcAO(vec3 pos, vec3 normal) {
    float occ = 0.0;
    float sca = 1.0;

    for(int i=0; i<5; i++) {
        float hrconst = 0.03; // larger values = AO
        float hr = hrconst + 0.15*float(i)/4.0;
        vec3 aopos =  normal * hr + pos;
        float dd = calcSDF( aopos ).x;
        occ += (hr-dd)*sca;
        sca *= 0.95;
    }
    return clamp(1.0 - occ*1.5, 0.0, 1.0);
}


// cut1 and cut2 define the center cone and the max width of the light
// they are cosines of the corresponding angles, so a center cone of
// 15 degrees and a max width of 30 degrees would correspond to
// cut1 = 0.9659258 and cut2 = 0.8660254
// lr is the normalized light ray
float calcDirLight(vec3 p, vec3 lookfrom, vec3 lookat, in float cut1, in float cut2) {
    vec3 lr = normalize(lookfrom - p);
    float intensity = dot(lr, normalize(lookfrom - lookat));
    return smoothstep(cut2, cut1, intensity);
}


// https://iquilezles.org/articles/rmshadows
float calcSoftshadow(in vec3 ro, in vec3 rd, in float mint, in float tmax, float w)
{
	float t = mint;
    float k = 1/(10*w);  // "softness" of shadow. smaller numbers = softer

    // unroll first loop iteration
    float h = calcSDF(ro + rd*t).x;
    float res = min(1., k*h/t);
    t += h;
    float ph = h; // previous h
    
    for( int i=1; i<60; i++ )
    {
        if( res<0.01 || t>tmax ) break;        

        h = calcSDF(ro + rd*t).x;
        float y = h*h/(2.0*ph);
        float d = sqrt(h*h-y*y);
        res = min(res, k*d/max(0.0, t-y));
        ph = h;
        t += h;
    }
    res = clamp( res, 0.0, 1.0 );
    return res*res*(3.0-2.0*res);  // smoothstep, smoothly transition from 0 to 1
}

float calcSoftshadowV2(in vec3 ro, in vec3 rd, float mint, float maxt, float w)
{
    float res = 1.0;
    float t = mint;
    for( int i=0; i<256 && t<maxt; i++ )
    {
        float h = calcSDF(ro + t*rd).x;
        res = min( res, h/(w*t) );
        t += clamp(h, 0.005, 0.50);
        if( res<-1.0 || t>maxt ) break;
    }
    res = max(res,-1.0);
    return 0.25*(1.0+res)*(1.0+res)*(2.0-res);
}

float calcSoftshadowV3(in vec3 ro, in vec3 rd, float mint, float maxt, float w) {
    float res = 1.0;
    float ph = 1e20;
    float t = mint;
    for( int i=0; i<256 && t<maxt; i++ )
    {
        float h = calcSDF(ro + rd*t).x;
        if( h<0.001 )
            return 0.0;
        float y = h*h/(2.0*ph);
        float d = sqrt(h*h-y*y);
        res = min( res, d/(w*max(0.0,t-y)) );
        ph = h;
        t += h;
    }
    return res;
}


vec3 calcLight(Light lightSource, vec3 pos, vec3 normal, vec3 rDirRef, float ambientOcc, vec3 material, float kSpecular) {
    float kDiffuse = 0.4,
        kAmbient = 0.005;

    vec3 iSpecular = 6.*lightSource.col,  // intensity
        iDiffuse = 2.*lightSource.col,
        iAmbient = 1.5*lightSource.col;

    float alpha_phong = 20.0; // phong alpha component


    vec3 lRay = normalize(lightSource.pos - pos);
    
    float light = calcDirLight(pos, lightSource.pos, lightSource.dir, cos(lightSource.focus), cos(lightSource.spread));
    vec3 lDirRef = reflect(lRay, normal);

    float shadow = 1.0;
    if (light > 0.001) { // no need to calculate shadow if we're in the dark
        shadow = calcSoftshadowV3(pos, lRay, 0.01, 3.0, lightSource.size);
    }
    vec3 dif = light*kDiffuse*iDiffuse*max(dot(lRay, normal), 0.)*shadow;
    vec3 spec = light*kSpecular*iSpecular*pow(max(dot(lRay, rDirRef), 0.), alpha_phong)*shadow;
    vec3 amb = light*kAmbient*iAmbient*ambientOcc;

    return material*(amb + dif + spec);
    
}


vec4 getNormal(vec3 pos) { 
    vec2 dist = calcSDF(pos);
    vec2 e = vec2(EPSILON, 0.0);

    vec3 normal = dist.x - vec3(
        calcSDF(pos-e.xyy).x,
        calcSDF(pos-e.yxy).x,
        calcSDF(pos-e.yyx).x);

    return vec4(normalize(normal), dist.y);
}

vec3 getNormal2(vec3 p) {
    vec2 e = vec2(EPSILON, 0.0);
    vec3 n = vec3(calcSDF(p).x) - vec3(calcSDF(p - e.xyy).x, calcSDF(p - e.yxy).x, calcSDF(p - e.yyx).x);
    return normalize(n);
}

vec3 getNormal3(vec3 pos) { 
    vec2 dist = calcSDF(pos);
    vec2 e = vec2(EPSILON, 0.0);

    vec3 normal = dist.x - vec3(
        calcSDF(pos-e.xyy).x,
        calcSDF(pos-e.yxy).x,
        calcSDF(pos-e.yyx).x);

    return normalize(normal);
}


float rMarch(vec3 rOrig, vec3 rDir) {
    float dOrig = 0.0; // distance from ray origin

    for(int i=0; i<MAX_STEPS; i++) {
        vec3 rPos = rOrig + rDir * dOrig;
        float dSurf = calcSDF(rPos).x;
        dOrig += dSurf;
        if(dOrig > MAX_DIST_TO_TRAVEL || abs(dSurf) < MIN_DIST_TO_SDF*clamp(((dOrig*dOrig-3)*LOD_MULTIPLIER),1,MAX_DIST_TO_TRAVEL*MAX_DIST_TO_TRAVEL*LOD_MULTIPLIER)) break;
    }

    return dOrig;
}


vec3 render(vec3 rOrig, vec3 rDir) {
    vec3 col = vec3(0.005);

    float dist = rMarch(rOrig, rDir);

    // light 1
    Light light1;
    light1.size = 0.01;
    light1.pos = vec3(5.*cos(-u_time), 4, 5.*sin(-u_time)); // light position
    light1.col = vec3(0.6157, 0.0, 0.0);
    light1.dir = vec3(0.5, 0.0, 0.0);
    light1.focus = radians(15.0);
    light1.spread = radians(30.0);
    
    Light light2;
    light2.size = 0.01;
    light2.col = vec3(1);
    light2.dir = vec3(-15, 20, -25);
    light2.pos = vec3(100, 50 , 20);
    light2.focus = radians(10.0);
    light2.spread = radians(20.0);

    
    // flashlight
    Light fLight;
    fLight.size = 0.0001;
    fLight.pos = u_camPos;
    fLight.col = vec3(0.6431, 0.6118, 0.498);
    fLight.dir = u_camPos + u_camTarget;
    fLight.focus = radians(15.0);
    fLight.spread = radians(30.0);



    if (dist<MAX_DIST_TO_TRAVEL) {
        vec3 pos = rOrig + rDir * dist; // surface point location
        vec4 normalVal = getNormal(pos);
        vec3 normal = normalVal.xyz; //surface normal
        vec3 rDirRef = reflect(rDir, normal); // reflected ray
        //float matID = normalVal.w;

        float ambientOcc = calcAO(pos, normal);

        col += calcLight(light1, pos, normal, rDirRef, ambientOcc, vec3(1.0, 1.0, 1.0), 0.5);
        col += calcLight(light2, pos, normal, rDirRef, ambientOcc, vec3(1.0, 1.0, 1.0), 0.5);
        if (u_flashlight>0) {            
            col += calcLight(fLight, pos, normal, rDirRef, ambientOcc, vec3(1.0, 1.0, 1.0), 0.5);    
        }
        //col = abs(normal);
    }
    return clamp(col, 0.0, 1.0);
}


// Camera system explained here:
// https://www.youtube.com/watch?v=PBxuVlp7nuM
// Old module and has been replaced
vec3 rDir(vec2 uv, vec3 rOrig, vec3 lookat, float zoom) {
    vec3 forward = normalize(lookat-rOrig),
        right = normalize(cross(forward, vec3(0, 1., 0))),
        up = cross(right, forward),
        center = forward*zoom,
        intersection = center + uv.x*right + uv.y*up,
        dir = normalize(intersection);
    return dir;
}

// method that can generat uv coordinates with an offset for supersampling
vec2 getUV(vec2 offset) {
    return ((gl_FragCoord.xy + offset) - 0.5 * u_resolution.xy) / u_resolution.y;
}

// new camera module that is cleaner to call
vec3 rCam(vec2 offset) {
    vec2 uv = getUV(offset);
    vec3 rOrig = u_camPos;
    vec3 lookat = rOrig+u_camTarget;
    float zoom = max(0.5,(u_scroll*0.05)+0.5);
    vec3 forward = normalize(lookat-rOrig),
        right = normalize(cross(forward, vec3(0, 1., 0))),
        up = cross(right, forward),
        center = forward*zoom,
        intersection = center + uv.x*right + uv.y*up,
        dir = normalize(intersection);
    return dir;
}

mat2 rotMatrix(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

// can super sample at different levels to reduce aliasing
vec3 superSample(int AA)
{
    vec3 col = vec3(0.0);
    float bxy = int(gl_FragCoord.x + gl_FragCoord.y) & 1;
    float nbxy = 1. - bxy;
    switch (AA) {
        case 0:
            col = render(u_camPos, vec3(0.0));
            col = vec3(getUV(vec2(0.0)), 0.0);
            break;
        case 1:
            col = render(u_camPos, rCam(vec2(0.0)));
            break;
        case 2:
            col = (render(u_camPos, rCam(vec2(0.33 * nbxy, 0.))) + render(u_camPos, rCam(vec2(0.33 * bxy, 0.66))));
            col /= 2;
            break;
        case 3:
            
            col = (render(u_camPos, rCam(vec2(0.66 * nbxy, 0.))) +
                  render(u_camPos, rCam(vec2(0.66 * bxy, 0.66))) +
                  render(u_camPos, rCam(vec2(0.33, 0.33))));
            col /= 3;
            break;
        case 4:
            vec4 e = vec4(0.125, -0.125, 0.375, -0.375);
            col = render(u_camPos, rCam(e.xz));
            col += render(u_camPos, rCam(e.yw));
            col += render(u_camPos, rCam(e.wx));
            col += render(u_camPos, rCam(e.zy));
            col /= 4;
            break;

    }

    return col;
}

void main() {
    vec2 uv = getUV(vec2(0.0));


    vec3 rOrig = u_camPos; // Works with WASD without old camera rotation
    //rOrig = rOrig / ((u_scroll+1)*0.1); // New scroll zoom.

    // Old code for camera rotation with mouse.
    // rOrig.yz *= rotMatrix(mouse.y*3.14);
    // rOrig.xz *= rotMatrix(mouse.x*2.*3.14);
    //vec3 rDir = rDir(uv, rOrig, u_camDir, max(0.06,u_scroll*0.05));
    
    //vec3 rDir = normalize(vec3(uv.x-.15, uv.y-.2, 1)); // New constant rDir
    //vec3 rDir = normalize(vec3(uv.x+u_camDir.x, uv.y+u_camDir.y, 1));

    //old uv rendering setup
    //vec3 col = render(rOrig, rDir(uv, rOrig, rOrig+u_camTarget, max(0.5,(u_scroll*0.05)+0.5)));
    //old rendering call using new camera module
    //vec3 col = render(rOrig, rCam(vec2(0.0)));

    //4x supersampling
    // vec4 e = vec4(0.125, -0.125, 0.375, -0.375);
    // vec3 col = render(rOrig, rDir(getUV(e.xz), rOrig, rOrig+u_camTarget, max(1,u_scroll*0.05)));
    // col += render(rOrig, rDir(getUV(e.yw), rOrig, rOrig+u_camTarget, max(1,u_scroll*0.05)));
    // col += render(rOrig, rDir(getUV(e.wx), rOrig, rOrig+u_camTarget, max(1,u_scroll*0.05)));
    // col += render(rOrig, rDir(getUV(e.zy), rOrig, rOrig+u_camTarget, max(1,u_scroll*0.05)));
    // col/=4;

    vec3 col = superSample(u_renderMode);

    col = pow(col, vec3( 1.0 / 2.2));	// gamma correction

    //col = vec3(uv,0.0);
    
    
    fragColor = vec4(col,1.0); 
}